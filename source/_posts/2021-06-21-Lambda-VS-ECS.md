---
title: Lambda VS ECS
date: 2021-06-21 11:48:35
tags:
- 云计算
---
# Lambda 的好处

- 按使用付费（云计算都有这个特点）。
- 把资源（ CPU 或内存分配）的 quota 封装得很好。
- 无需关心监控和运维。
- 自动扩展（无需关心物理 nodes。node 既意味着系统可拆解，也意味着系统可联结）。

# Lambda 的坏处

- 多步执行环节很慢
- 特定 function 的执行隔离不好，可能多个用户相互踩踏

# ECS

ECS 云基础设施在架构上更易扩展，只要稍加改造就能和系统集成。

参考：[《我们为什么从 Lambda 迁移到了 ECS？》][1]

  [1]: https://www.infoq.cn/article/A73fcOBEa2A6PFj4bqqZ
