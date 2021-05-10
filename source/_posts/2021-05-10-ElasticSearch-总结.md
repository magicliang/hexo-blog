---
title: ElasticSearch 总结
date: 2021-05-10 15:57:39
tags:
- JVM
- Java
- ElasticSearch

---
# ES 的定位

1. ES 是 build on top of Lucene 建立的可以集群化部署的搜素引擎。
2. ES 可以是 document store，可以结构化解决数据仓库存储的问题。
3. ES 是海量数据的分析工具能够支持：搜索和实时统计。

ES 的架构有优越的地方：
1. 自己使用 pacifica 协议，写入完成就达成共识。
2. 节点对内对外都可以使用 RESTful API（or json over http）来通信，易于调试。

# ES 的索引相关

[ElasticSearch 索引.xmind](ElasticSearch 索引.xmind)

![ElasticSearch 索引.png](ElasticSearch 索引.png)