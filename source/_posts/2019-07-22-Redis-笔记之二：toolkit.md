---
title: Redis 笔记之二：toolkit
date: 2019-07-22 23:22:37
tags: Redis
---
## Redis 笔记之二：toolkit

标签（空格分隔）： Redis
---
# redis-server

常用的配置文件内容：

- port 一般是 6379
- logfile 日志文件（redis 的日志文件和 Kafka 不一样，和存储文件是分离的）
- dir Redis 工作目录（存放持久化和日志文件）
- daemonize 是否以守护进程的方式来启动 Redis

redis 的 minor 版本号如果是奇数，则含有实验性 feature 的非稳定版本；如果是偶数，则是稳定版本。所以我们应该在生产环境使用偶数版本，而在实验性环境里使用奇数版本。

# redis-cli

cli 有两种工作形式：interactive 和 non-interactive。

使用 redis-cli 关闭 redis 的时候，redis 会做优雅关闭的操作，优雅关闭主要包括：

1. 断开客户端连接。
2. 存储数据到 rdb 文件。

所以要尽量用 shutdown 命令，而不要直接 kill（待完成，kill 的分类）。

# redis-benchmark

基准测试工具

# redis-check-aof

AOF 持久化文件校验和**修复**工具

# redis-check-rdb

redis RDB 持久化文件检测和**修复**工具

# redis-sentinel

启动 redis 哨兵

# 其他 redis 模块


neural-redis        Online trainable neural networks as Redis data types.    把可训练的神经网络作为 Redis 的数据类型。
RediSearch      Full-Text search over Redis 在 Redis 之上的全文本搜索引擎
RedisJSON       A JSON data type for Redis Redis 的 Json 数据类型

rediSQL     A redis module that provide full SQL capabilities embedding SQLite 通过嵌入 SQLite 提供全 SQL 支持能力
redis-cell      A Redis module that provides rate limiting in Redis as a single command.    支持在 Redis 中一键限流。
RedisGraph      A graph database with a Cypher-based querying language using sparse adjacency matrices 一个使用基于密码的 使用稀疏邻接矩阵查询语言的图数据库
RedisML     Machine Learning Model Server 机器学习模型服务器
RedisTimeSeries     Time-series data structure for redis  Redis 的时序数据库
RedisBloom      Scalable Bloom filters  Redis 的可伸缩的布隆过滤器
cthulhu     Extend Redis with JavaScript modules Redis 的 JavaScript 模块
redis-cuckoofilter      Hashing-function agnostic Cuckoo filters.       哈希函数的不可知布谷过滤器（？）
RedisAI     A Redis module for serving tensors and executing deep learning graphs   一个提供张量和执行深度图的 Redis 模块 
redis-roaring       Uses the CRoaring library to implement roaring bitmap commands for Redis.  使用 CRoaring 库实现 Redis 的 roaring 位图命令
redis-tdigest       t-digest data structure wich can be used for accurate online accumulation of rank-based statistics such as quantiles and cumulative distribution at a point. 一个可以被用来精确累积基于排名的统计（诸如分位点或者某一个点的累积分布）的 t 摘要数据结构
Session Gate        Session management with multiple payloads using cryptographically signed tokens. 
使用密码学签名的令牌的多重负载的会话管理

countminsketch      An apporximate frequency counter    
一个近似频率计数器

ReDe        Low Latancy timed queues (Dehydrators) as Redis data types. 低延迟的计时队列
topk        An almost deterministic top k elements counter  
一个有确定性的 topk 元素计数器

commentDis      Add comment syntax to your redis-cli scripts.   

redis 客户端的评论语法