---
title: Redis 笔记之二：toolkit
date: 2019-07-22 23:22:37
tags: Redis
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