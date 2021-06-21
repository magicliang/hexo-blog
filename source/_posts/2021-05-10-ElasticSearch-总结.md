---
title: ElasticSearch 总结
date: 2021-05-10 15:57:39
tags:
- JVM
- Java
- ElasticSearch

---
# ES 思维导图

[ElasticSearch总结.xmind](ElasticSearch总结.xmind)

![ElasticSearch总结.png](ElasticSearch总结.png)

# ES 的定位

1. ES 是 build on top of Lucene 建立的可以集群化部署的搜素引擎。
2. ES 可以是 document store，可以结构化解决数据仓库存储的问题。在 es 中一切皆对象，使用对象对数据建模可以很好地处理万事万物的关系。

3. ES 是海量数据的分析工具能够支持：搜索、分析和实时统计。

ES 的架构有优越的地方：
1. 自己使用 pacifica 协议，写入完成就达成共识。
2. 节点对内对外都可以使用 RESTful API（or json over http）来通信，易于调试。
3. 因为它有很多很好的默认值，所以开箱即用。
4. 它天生就是分布式的，可以自己管理多节点。

# ES 的架构

ES 是基于 Lucene 的，集群上的每个 node 都有一个 Lucene 的实例。而 Lucene 本身是没有 type 的，所以 ES 最终也去掉了 type。

ES 中每个节点自己都能充当其他节点的 proxy，每个节点都可以成为 primary。用户需要设计拓扑的时候只需要关注种子节点和 initial master 即可。

# ES 中的搜索

## 全文搜索

按照[《全文搜索》][1]中的例子，使用 match 总会触发全文搜索。因为在Elasticsearch中，每一个字段的数据都是默认被索引的。也就是说，每个字段专门有一个反向索引用于快速检索。想不要做索引需要对任意的 properties 使用 `"index": "not_analyzed"`。

## 精确（短语）搜索

精确查询的方法有：

[短语查询][2]：
```json
{
    "query" : {
        "match_phrase" : {
            "about" : "rock climbing"
        }
    }
}
```

**term 查询（这种查询是客户端查询里最常用的）**：
```json
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "about" : "rock climbing"
          }
        }
      ],
      "must_not": [],
      "should": [],
      "filter": []
    }
  },
  "from": 0,
  "size": 10,
  "sort": [],
  "profile": false
}
```
另一种 phrase 查询：
```json
{
 "from": 0,
 "size": 200,
 "query": {
  "bool": {
   "must": {
    "match": {
     "about": {
      "query": "rock climbing",
      "type": "phrase"
     }
    }
   }
  }
 }
}
```

精确和不精确查询有好几种方法，详见[《elasticsearch 查询（match和term）》][3] 和[《finding_exact_values》][4]。

## search api 的搜索

参考[《空查询》][5]。

# 倒排索引简析

倒排索引的 key 是 term，value 是文档的指针，可以参考这个[《倒排索引》][6]文档。

过滤机制
头机制
x-pack
version 机制

# 容量与分片

## 为何分片不宜过大？

1. 增加索引读压力-不利于并行查询。
2. 不利于集群扩缩容（分片迁移耗费较长时间）
3. 集群发生故障时，恢复时间较长

类似的问题也会发生在 Redis 之类的架构方案里。

  [1]: https://www.elastic.co/guide/cn/elasticsearch/guide/current/_full_text_search.html#_full_text_search
  [2]: https://www.elastic.co/guide/cn/elasticsearch/guide/current/_phrase_search.html
  [3]: https://www.cnblogs.com/yjf512/p/4897294.html
  [4]: https://www.elastic.co/guide/en/elasticsearch/guide/current/_finding_exact_values.html#_finding_exact_values
  [5]: https://www.elastic.co/guide/cn/elasticsearch/guide/current/_empty_search.html
  [6]: https://www.elastic.co/guide/cn/elasticsearch/guide/current/inverted-index.html