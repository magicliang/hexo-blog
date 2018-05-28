---
title: Fabric 中的 peer
date: 2018-04-09 17:55:01
tags:
- Hyperledger Fabric
- 区块链
---
每个 peer 可以拥有若干个 chaincode，也可以拥有若干个 ledger，但并不是一开始就拥有的，而是逐渐被创建出来的。chaincode 一定会定义一个 asset，也就生成了 ledger。一个peer 可以拥有 ledger 而无 chaincode，可见也并不是必然由 chaincode 生成 ledger。比如同一个组织里面多个 peer，只有一个安装了 chaincode（只有这个 peer 可以当作 endorser），其它的peer一样可以拿到 ledger。

peer 的流程架构图大致上是：

![](https://ws1.sinaimg.cn/large/66dd581fly1fq6hnit0eej20ng0aataa.jpg)

为了预防有 peer 的数据不一致，有可能需要 client application 向多个 peer 进行查询。

channel 可以认为是一系列 peers 的逻辑组合，orderer 可以被认为是跨channel的。同一个 channel 的 peers 共享完全一样的账本。

![](https://ws1.sinaimg.cn/large/66dd581fly1fq6hygjdi4j21bq0hujvb.jpg)

不同的组织完全可以基于同样的账本copy，产生不同的 application。

Fabric 有 identity，identity 有 principal。

transaction 到达 orderer 的顺序，并不一定就是 transaction 在 block 里的顺序。

现在整个共识过程分为proposal-packaging-validation三个阶段。第一步和第三步都是去中心化的，第二步等局部中心化只是为了模块化共识算法的实现，也为了解耦第一和第三步，让它们并行执行。实际上，endorser和commitor在逻辑上还可以进一步分离，又进一步提升了并发性。

在 validation 阶段，不合格的 transaction 会被保留（在区块中？）以备审计，而不会被应用中账本上。

peer并不都要连到 orderer 上，这就要求 gossip 协议出场了。

![](https://ws1.sinaimg.cn/large/66dd581fly1fq6i20ya1jj21bq0lcwly.jpg)