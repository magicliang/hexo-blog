---
title: TiDB 与 bbb
date: 2021-01-26 11:02:16
tags:
- 系统架构
- 存储
---
# 两种业务场景和相应的架构模式

偏重事务处理（online transactional processin, OLTP）：此类数据库将不同属性连续存储，也即按行存储。按行存储可以使得插入/更新/删除更快，毕竟一条数据的所有属性是连续存储的。这种存储模型也叫做 N-Ary Storage Model (NSM)。

偏重数据分析（online analytical processing, OLAP）：此类数据库将不同数据的同一属性连续存储，也即列存储。这种存储可以使得查询操作只读关心的数据属性，而不是一整条数据，减少浪费；按列储存可以更好地支持复杂查询。这种存储模型也叫做 Decomposition Storage Model (DSM)。

# TiDB 的基础架构

Log-Structured Merge-tree (LSM-tree)是一种存储结构，由于其优越的写性能被很多大型分布式存储系统采用，包括Google 的 BigTable, Amazon的 Dynamo, Apache 的 HBase 和Cassandra等；MongoDB的WiredTiger引擎则支持B-tree 和 LSM-tree 两种模式；TiDB 则使用了著名的RocksDB。

Balde 2.0 是基于社区TiDB版本，独立重构存储层（改动较大，下面会介绍），深度定制SQL层（改动较小，复用较多的功能）的分布式数据库。bbb 2.0 主要结构如图所示：

![tidb-architecture.png](tidb-architecture.png)

TiSQL 又叫 TiDB Server，基本实现了 parser、optimizer、executor、cache，是无状态可以无限扩展。但 TiDB 本身并不是 monolithic deployment 部署的，而是和底层的 tikv 分离部署的-这和 MySQL 的架构不一样。

在最初版本的实现里面，TiSQL 的接口层稳定以后，就能接入 HBase，这点和 Tair 是很像的。

bbb-root 是一个 pd（placement driver） server 的分布式集群，彼此之间也使用 raft 靠 leader 来维护元数据，元数据是负载均衡至关重要的信息。

- 采用类似于Google F1/Spanner 的分布式KV存储 (即bbb-kv) + 无状态计算节点 (即bbbSQL) 模型；
- 用户表中每一行数据，对应一个 Data K/V（Key:   tablePrefix{TableID}_recordPrefixSep{RowID}
Value: [col1, col2, col3, col4]） + N个Index K/V（Key: tablePrefix{tableID}_indexPrefixSep{indexID}_indexedColumnsValue Value: RowID），N是二级索引的个数(N>=0)；这些 kv 是以 map 的形式组成了 sstable，由 Rocksdb 支持（基于谷歌的 LevelDB，由 facebook 出品）。
- -bbb-kv 以Ranged Partition的方式将整个key空间分为多个Region(Partition/Shard)，每个Region对应一段连续范围的key；这点很类似 HBase。
- 每个Region都有多个副本，副本间通过共识协议 Raft 来达到CAP的平衡；多个 region 组成一个 raft-group。
- 每个Region的数据，以一棵独立LSM-tree的形式存储；
- Region在容量超出水位线时，会进行分裂，变成两个独立的Region；
- bbb-root 管理集群元数据信息，提供Region的路由服务以及全局授时服务；
- bbb-sql处理SQL解析、优化和执行，将SQL请求转化为一系列的K/V请求，再根据路由信息，发送对应的bbb-kv 节点；
- 提供乐观/悲观锁模型，支持分布式事务，支持Read Committed隔离级别。默认使用乐观事务模型，对于写写冲突，只有事务提交时才检测冲突。支持完整的 ACID 语义（TiKV 是个 Transactional Storage Engine）。
- 多节点同步都依赖于 Raft，批量事务处理则依赖于谷歌的 Percolator  事务处理模型。
- tidb 本身不能很好地支持自增主键（这会导致单一的写流量集中到一个节点上），改造的方法是引入唯一索引。

# LSM-tree 和一些典型实现

## LSM-tree模型

LSM-tree [1] 是一种out-of-place（相对于原地更新，暂且译作外地更新） update的结构，它的特点是把新数据写到新的位置，在后台做merge，而不是原地更新。

所谓out-of-place，是相对B-tree等in-place update的结构而言的，in-place的结构只保持一个最新版本，查询效率更高。但是因为有了随机写，in-place update牺牲了写性能。

Out-of-place 没有随机写，但是也带来了一些其他开销，尤其是读可能需要查询多个层级。

注意，C0是内存中的，而C1及其他更大的层级，都是需要持久化存储，且越靠近内存的层数据量越小。

![what-is-lsm-tree.png](what-is-lsm-tree.png)

Tree的含义：每一层是一颗树。事实上最原始的paper [1]中，每一层都是一个B-tree，只是后来的很多实现中，已经不用B-tree了，但是名称保留了。

层与层间的增量关系：C0实际上是C1的增量，C1是C2的增量。增量数据可以是Insert/Update/Delete等不同操作产生的。

Log-Structured 的含义： 像写log一样去顺序磁盘，避免随机写，因为随机写性能太差。

Merge 是指把上层的增量数据，合并到其基线版本（所以基线版本是 C<sub>k</sub>）中去的过程。例如，C0的数据被merge到C1中。这个过程也称为 Compaction，不过现在已经有跨层compaction等变体。 

FAQ: 为什么要Compaction/Merge: 

1. 提高查询效率：虽然每一层是个有序的集合，但是层级多了后，查询可能要依次查询每一个层级。通过merge，让数据从较多个有序集合，变成较少个有序集合，提高效率。

2. 释放空间：重复写的数据，其旧版本可以在Compaction时删除；用户Delete的数据，需要做物理删除。

## 一些开源的LSM-tree 实现

LSM-Tree 因为优秀的性能被广泛采用，其中著名的开源产品包括Google的 Jeff Dean的杰作 LevelDB，Facebook 基于LevelDB开发的 RocksDB 等。

FaceBook 还开发了 MyRocks，在部分业务场景下用 RocksDB 替 InnoDB 作为 mysql 的引擎。下表列出了一些原始的 LSM-tree 概念与LevelDB中概念的对应关系。

|LSM-tree概念|LevelDB/RocksDB对应|
|:--:|:--:|
|C0|Mem Table (分为Mutable/Immutable)|
|C1|Level-0 (Tiered)|
|C2|Level-1 (Leveled）|
|Ck|Level-(k-1) (Leveled)|

# LSM-tree 的一些问题和 bbbKV 的设计取舍

bbbKV的存储也是采用LSM-tree的方式。LSM-tree本身是灵活的，自身也存在一些问题，在设计和工程实现方面需要进行取舍。

这些问题可以用“三个放大”来描述。

## 三个放大

LSM-tree 存储系统在设计实现时需要考虑写放大、读放大和空间放大三个因素，这三个因素都是比率：

- 写放大： 磁盘数据的写入量 / 用户写入的数据量

- 读放大： 磁盘数据的读入量 / 用户实际要读取的数据量

- 空间放大：磁盘空间占用 / 有效的用户数据量

其中写放大往往是最严重的，对它的计算和分析也相对较多。

### 写放大的计算及最优化

在LSM的原文中，作者提到层与层之间的扇出系数(size ratio)是常量时，写放大最优。但是具体取什么常量是最优的，并没有明确。

Size Ratio是指相邻两层之间大小的比率，比如，C0层大小是1GB, C1层大小是10GB，那么 Size Ratio 就是10。

FaceBook的文档中有获得最优写放大倍数具体的计算方式，详细推导参见[2] [3]。这里大致列下推导过程：         

假定LSM-tree 每一层的扇出系数相同，都是
f
，即
f=sizeof(C 
l+1
​   
 )/sizeof(C 
l
​   
 )
，而总的持久化层数为
n
。

考虑到数据最终会落到最底层，那么最终写放大倍数为：

        
wa=n∗f

 假设磁盘容量是内存容量的 t 倍，或者说内存/磁盘容量比是1/t，那么
t=f 
n
 ,即f=t 
1/n
 
。写放大系数
wa
变为：

          
wa=n∗t 
1/n
 

t 是已知常量，把
wa
 对 
n
求导数，经过一些变换，可以得到式子：

       
n 
′
 
(wa) 
′
 
​   
 =t 
1/n
 − 
n
1
​   
 ×ln(t)×t 
1/n
 =t 
1/n
 ×(1− 
n
ln(t)
​   
 )

当
n=ln(t)
时，导数为0，得到最小的写放大倍数。

在这种情况下，每层的扇出系数是
f=t 
1/n
 =t 
1/ln(t)
 =e
。注意，虽然rocksdb的默认扇出系数是10，但是数学上最佳值是自然对数e。

如果 t = 1024，则对应层数 n 的最佳值是
ln(1024)=6.93
，取整为7层。

注意上面假设的1024是个较大的比值，即磁盘容量为内存容量的1024倍。

### 读放大

假设LSM-tree有n层。由于每一层的文件都是有序的且有元数据。对于一个点查， 在每层最多打开一个文件，因此读放大是
O(n)
。

常见的缓解读放大方法包括：

Cache： 尽量缓存容量较小层级的数据在内存中，因为它们访问频率较高。

Bloom Filter: **可以根据hash值提前确定一些key不存在，从而缓解一部分点查的读放大；但是解决不了Scan类型的范围查询的读放大**。（这个结论非常重要，做读放大的优化，一定要先把问题分成两类问题）。

Range Filter: 例如SuRF等，可以优化查询范围查询的性能。  

总的来说，层级越少，对读越友好。Hash 对单一 key 查找有极强的优化作用，但 range 查找可能要借助一些空间局部性优化手段。

### 空间放大

空间放大主要有两个因素：

不同 Level 有同一key的多个版本;

用户已经删除的数据没有做物理删除，只是记录了log或者在做了删除标记。

空间放大一般相对有限。对于第一个因素，层级越少则重复的key越少，相应地，它导致的空间放大越低。

对于第二个因素，用户已删除的数据何时在物理上被删除，主要依赖于Compaction机制。

## bbbKV：每分片独立的LSM-tree 

有些分布式存储系统选择使用一个 LSM-tree存储整个节点的所有分片的数据，比如 TiKV（架构上简单）；**也有些选择一个 LSM 实例只管理节点上的某个分片，例如 Hbase。（架构上复杂）**

bbb 选择了后者，即一个表有多个分片，每个分片对应一个 LSM-tree，理由是：

- 表（索引）的迁移、删除效率更高，可以直接通过物理文件的传输、删除实现，无需进行数据遍历，性能优势明显。

- 不同的表物理上就完全分开，隔离性更好，可以做更细粒度的控制，比如表级的缓存预热。

- 限定单个 LSM 的大小后可以进行深度定制，在几乎不影响读放大、空间放大的前提下可以大大降低写放大

**付出的代价主要是实现上的复杂性，比如全局元数据管理和跨分片操作（分裂、合并）相对单实例管理所有分片需要更精心的设计。**

## bbbKV：大 Memtable、少层级

bbbKV选择了较大的Memtable(即前图中的C0)，大部分时候只有一个持久化层(称之为Level-1)。取舍 1。主要原因如下：

- 服务器能够为bbbKV分配的内存、磁盘容量比较确定，可以算出内存/磁盘容量比。

- 典型的内存/存储的容量比：按照2.9TB NVME磁盘， 256GB内存计算，内存与存储容量比接近 1/10，即 t 接近于 10。

- 由于对schema的感知，Memtable 中可以只保存修改的列，而不是整行，所以相当于获得了更高的内存/磁盘容量比。这一点leveldb/rocksdb 这种纯K/V接口的引擎是做不到的。取舍2。

- 写流量有明显的局部性，更新的 key 较为集中，不会出现 major compaction 关联大量 L1 文件，每个文件只关联少量数据的情况。取舍 3。

- 每个分片一个 LSM 实例，限定了单个实例的大小（目前暂定2G，可能根据实际运行情况调优），也就限制了总的文件数量（千级别），不会对读造成太大的影响。取舍 4。而 leveldb/rocksdb 原生设计需要支持单实例数百上千G的容量，不分级读会很慢。

在此前提下，与 TiDB(TiKV) 相比，这样设计有如下取舍：

- 写放大大幅降低：每次 compaction 涉及的 SST 文件中实际不需要合并的数据减少；每个 key 经过一次 compaction 就达到了“最终”层。

- 空间放大略微降低：bbb 没有空间放大，比 TiDB(rocksdb) 的 1.1 要好些。

- 读放大相当：考虑在数据量 1T 的进程上查询一个不在 memtable/immutable 的 key

 - 由于 region 已经确定，假定是满 region，bbb 需要从 1000 个(2G/2M) FileMeta 中找到目标 SST，共要 10 次逻辑查询和 1 次物理查询（ps: SST 文件没有多 level 重叠，bloom filter 的必要性下降了）-这证明了 bloom filter 能够优化 leveling i/o，不适合优化单 i/o。

 - TiDB 所有 region 共用一个 rocksdb，导致潜在的候选文件更多(1T*1.1/8M ~ 144,000)，但由于 Level 和 fractional cascading 机制，逻辑查询较少。物理查询大部分情况下也只需要 1 次，但 bloom filter 误报或范围查询时，需要每层做一次物理查询。

 - bbb 查询耗时较稳定，TiDB 受 key 所在层级和查询方式影响较大。

  - 层级较低的“温” key TiDB 占优，能以较少的逻辑查询和相同的物理查询次数获得数据；

  - 范围查询 balde 需要的物理查询较少，优势明显；

  - 考虑到点查较多，且 bbb memtable 远大于 TiDB，读放大两者大致相当。

总体上 bbb 优势明显，关键在于充分利用已知要查询的数据属于哪个 region 的特性，重新调整了底层存储引擎；TiDB(TiKV) 整个进程用一个 rocksdb 的方式无法利用这点。

上面有了定性分析，下面我们定量地计算一下写放大。按照t= 10和前面的最优扇出系数 e 计算，最优的持久化层级
n=ln(10)=2.3
层，取整则是2层。相应地，可以把e向上取整 f=3，最终取整的写放大倍数是3*3=9倍。

如果BaldeKV 只使用一个持久化层：

- 扇出系数f=10，写放大倍数是10倍；

- 空间放大较小，没有各层间保存重复key导致的空间浪费；

- 读放大是1；

所以，bbbKV选择了只有一个持久化层Level-1。

应急处理：

如果出现大量的突发写，导致内存压力过大，而将 memtable 与磁盘上的 Level-1 做Compaction太慢，bbb-kv会临时启用Level-0，作为Level-1的增量。

Level-0 是个特殊的层，它允许同层的不同文件间key的重叠。所以写 Level-0 不需要任何Compaction，可以快速缓解内存压力。在高峰过后，可恢复正常的单个持久化层。

# comment

> 老牌的数据库产品oracle
> mysql使用的是B-tree加undo的方式实现存储mvcc，而LSM相对来说实现更简单，对于很多热点相对集中的业务，内存使用效率更高，可以借鉴B+tree引擎的思路去优化compaction
> 
> 长期来看，并不是非此即彼，它们的融合架构是比较好的方向，比如bbb中的SST存储结构，整体来看已经是支持快照的B+tree结构了；而优化了compaction影响后的架构可以支持更频繁的full
> compaction，跟oracle/mysql的checkpoint也就很像了。
> 
> 1）
> 关于先进和落后（打开链接只看到一点点评论，不知作者怎么论证落后和先进的），LSM在关系数据库领域应用并不少，只是发展的没那么早，不知道说落后是啥理由。例如，单机数据库：FaceBook的MyRocks(MySQL的底座换RocksDB，有对比测试，性能比较强悍)；分布式数据库领域：Google
> Spanner和阿里的OceanBase。
> 
> 2）相比之下，LSM-tree的设计更倾向于写优化，B-Tree则倾向于读优化。为什么近年来LSM-Tree受关注多，跟存储系统的变化也有关。我们逐渐从机械盘过渡到了SSD盘，SSD有几个机械盘所没有的特性，更需要优化写：1)
> 读写性能不均衡(写比读差很多，网上后数据); 2)
> 写需要做擦除(擦除的单位远大于磁盘扇区)，本身又是一次写放大；3)写寿命/擦除次数非常有限。事实上，我知道的做SSD
> 固件的人，基本都是在优化写性能和寿命。


