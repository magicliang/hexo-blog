---
title: Journal 与 EBS
date: 2021-01-29 17:55:34
tags:
- 存储
---
# EBS 的定义

EBS — Elastic Block Storage，简言之就是高可用、高性能、弹性可扩展的分布式块存储服务。对于业务来说，它就是一块磁盘，只不过将业务数据存储于远端网络节点，但是使用方法和体验与访问本地磁盘一样。

EBS 可以作为容器的存储盘，可以解决：

- 有状态容器的状态存储问题
- 海量存储问题：邮件系统、监控平台、数据库、用户录音、集成测试平台、MySQL 备份（需要测试 OLTP/OLAP 的交互操作和在线交易性能）

# EBS 的文件系统结构

在EBS分布式块存储系统中，最终存储业务写入数据的服务是ChunkServer。

单机存储引擎位于每个ChunkServer上，业务的数据读写请求到达ChunkServer后，最终通过单机存储引擎与操作系统文件系统交互来写入或读取数据。

业务申请的每一块ebs网络盘在我们的系统里都对应一个Volume。Volume本身是一个逻辑概念，每个Volume被切分成多个Chunk，Chunk最终对应到ChunkSever上文件系统中的一个真实文件，因此我们的单机存储引擎最终会管理这一系列Chunk文件的创建，读写，删除等操作。

![EBS-volume-chunk-server.png](EBS-volume-chunk-server.png)

