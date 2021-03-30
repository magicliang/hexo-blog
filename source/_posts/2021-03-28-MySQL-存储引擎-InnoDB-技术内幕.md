---
title: MySQL 存储引擎- InnoDB 技术内幕
date: 2021-03-28 16:22:25
tags:
- MySQL
- 数据库
---
# 前言

MySQL 是处理海量数据（尤其 是OLTP 写入）时仍能获得最佳性能的最佳选择之一，它的 CPU 效率可能其他任何基于磁盘的关系型数据库所不能匹敌的-但它应该能够匹敌 Redis。

Think Different 而不是 Think Differently，这意味着要思考不同的东西，而不只是思考不同的方式。

不要相信网上的传言，去做测试，根据自己的实践做决定。

change buffer 是 inert buffer 的升级版本。

# MySQL 体系结构和存储引擎

## 定义数据库和实例

- 数据库：物理操作系统文件或其他形式文件类型的集合。
- 实例：操作系统后台进程（线程和一堆共享内存）。
- 存储引擎：基于表而不是基于库的，所以一个库可以有不同的表使用不同的存储引擎。

InnoDB 将数据存储在逻辑的表空间中，这个表空间就像黑盒一样。

存储引擎不一定需要事务。比如没有 ETL 的操作，单纯的查询操作不需要考虑并发控制问题，不需要产生一致性视图。

NDB 存储引擎是一个集群存储引擎，类似 RAC 集群。不过与 Oracle RAC share everything 不同，NDB share nothing，而且把数据放在内存中。

如果不需要事务，文件系统就可以当做数据库。数据库区别于文件系统的地方就是，数据库可以支持事务（不代表必然使用事务）。

用户可以按照文档 16 章自己写自己的存储引擎。

# InnoDB 的存储引擎

InnoDB 是 transactional-safe 的 MySQL 存储引擎。

## InnoDB 存储引擎概述

InnoDB 当前支持每秒 800 次的写入，也可以存储 1tb 以上的数据。

InnoDB 的体系结构可以大体包括：

后台线程 + 内存池 + 文件

### 后台线程包括

#### master thread

负责异步地将缓冲池中的数据异步地刷新到磁盘，dirty page refresh、merging insert buffer。

#### IO thread

在 InnoDB 中大量使用 AIO 来处理 IO 写请求。

#### purge thread

purge 操作是从 master thread 里单独分离出来的一部分职能，专门处理 undo log。

#### page cleaner thread

将之前版本中的 dirty page refresh 的职责分离出来。

### 内存

#### 缓冲池

为了弥合 cpu 和磁盘的性能鸿沟，基于磁盘的数据库必然引入内存缓冲池。

主要的内存缓冲池有：

- innodb_buffer_pool
- redo_log_buffer
- innodb_additional_mem_pool_size

有了内存缓冲池，就允许出现脏页。把脏页刷新到磁盘上，是通过 checkpoint 机制实现的。

#### LRU list、free list 和 Flush list

innodb 使用这三种 list，来调度不同的脏页。

#### redo log buffer

这个 buffer 是 wal 写入磁盘之前的 buffer。注意 wal 的 buffer 刷新到磁盘，不是脏页的刷新到磁盘（checkpoint 实际上就是 dirty page refresh）。

通常情况下，每一秒钟这个 buffer 会被刷新到磁盘上（通过 page cleaner thread），只要用户每秒产生的事务量在这个缓冲大小之内即可。

总共有三种情况下会发生内容刷新：

- 一秒定时
- 事务提交
- buffer 的大小小于 1/2时

这代表了三种策略：

- 时间
- 空间阈值
- 持久化事件

#### additional mem pool

管理一些 buffer controll block。

## checkpoint 技术

checkpoint 保证，在灾难恢复时，过了 checkpoint 的 redo 日志才需要关注。这样可以减少宕机恢复时间。

重做日志不可能无限被使用，所以一旦要重用重做日志，必然带来强制的 checkpoint，导致脏页至少被刷新到 redolog 当前的位置。

标记 redolog 的位置方法是 LSN（log sequence number）。

有以下几种情况会触发 checkpoint：

- Master Thread 定时刷新脏页
- LRU 脏页列表大小不够
- redo log 大小不够
- 脏页数量太多

## innodb 关键特性

### insert buffer

Insert Buffer 既是内存缓冲池的一部分，也是物理页的一部分。

对于非唯一的辅助索引，为了减少随机插入，InnoDB 在插入更新数据页的时候，会想办法校验缓冲池里有没有该数据页。如果有，则先处理缓冲池里的数据；否则，在插入缓冲里插入一页，欺骗（mock）全流程，然后继续剩下的 buffer pool 操作。

### change buffer

change buffer 可以缓冲 dml 了，insert、delete 和 purge 都可以缓冲。

### insert buffer 的实现

全局有一个 insert buffer b+树，存放在 ibdata 中。

非唯一的辅助索引在插入到数据库中时，会构造一条记录，然后插入到这棵树中。当读写发生的是，只要需要读最终数据，都要触发 merging。这种索引的性能提升借助于不做唯一性检查。

### doublewrite

写入一个数据页不一定能够原子成功。有可能发生部分写失效（partial page write）。因为 redo log 是物理日志，所以强依赖于页的状态。

doublewrite 的意思是，重做发生时，需要先把页副本还原出特定的页，然后再 apply redo log。

innodb 在刷新脏页时，会先写入 double write buffer，然后双写到表空间里的 double write extent 里，最后再用 fsync 把脏页刷新到 ibd 数据文件里。

### 自适应哈希索引

innodb 会自动根据访问的频率和模式来自动地某些热点页建立哈希索引。

### 异步 io

native aio 需要操作系统的支持。

### 刷新邻接页（flush neighbor page）

机械硬盘需要这个功能，固态硬盘不怎么需要。

## 启动、关闭与恢复

默认的情况下，MySQL 会在关闭和重启时，把脏页刷新回磁盘。所以有时候 MySQL 重启的速度可能非常慢。

# 文件

现在默认的 binlog 格式是 row。

redolog 使用的是 ib_logfile1、ib_logfile2，循环使用。

# 表

tablespace 下分为 段 segment、区 extent 和页 page。

默认的行格式是 compact。

# 锁

注意意向锁之间的兼容性。

# 事务

redo 保证持久性。它的地址空间需要用来重用。

undo 保证原子性和 mvcc。它的地址空间需要被 purge 线程消除。