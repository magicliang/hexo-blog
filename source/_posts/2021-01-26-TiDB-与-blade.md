---
title: TiDB 与 blade
date: 2021-01-26 11:02:16
tags:
- 系统架构
- 存储
---
# TiDB 的基础架构

Log-Structured Merge-tree (LSM-tree)是一种存储结构，由于其优越的写性能被很多大型分布式存储系统采用，包括Google 的 BigTable, Amazon的 Dynamo, Apache 的 HBase 和Cassandra等；MongoDB的WiredTiger引擎则支持B-tree 和 LSM-tree 两种模式；TiDB 则使用了著名的RocksDB。

模型介绍如下：

![tidb-architecture.png](tidb-architecture.png)

- 采用类似于Google F1/Spanner 的分布式KV存储 (即Blade-kv) + 无状态计算节点 (即BladeSQL) 模型；
- 用户表中每一行数据，对应一个 Data K/V + N个Index K/V，N是二级索引的个数(N>=0)；
- -Blade-kv 以Ranged Partition的方式将整个key空间分为多个Region(Partition/Shard)，每个Region对应一段连续范围的key；
- 每个Region都有多个副本，副本间通过共识协议 Raft 来达到CAP的平衡；
- 每个Region的数据，以一棵独立LSM-tree的形式存储；
- Region在容量超出水位线时，会进行分裂，变成两个独立的Region；
- Blade-root 管理集群元数据信息，提供Region的路由服务以及全局授时服务；
- Blade-sql处理SQL解析、优化和执行，将SQL请求转化为一系列的K/V请求，再根据路由信息，发送对应的Blade-kv 节点；
- 采用悲观锁模型，支持分布式事务，支持Read Committed隔离级别


