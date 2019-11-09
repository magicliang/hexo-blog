---
title: Redis 笔记之十-哨兵 Sentinel
date: 2019-10-30 22:20:55
tags:
- Redis
---
Redis 有若干套高可用实现方案。2.8 开始提供哨兵功能（不要使用更低版本的哨兵，可能有 bug）。

# 基本概念

![此处输入图片的描述][1]

## 主从复制模式的问题

Redis 天然就带有主从复制的功能，但主从复制有若干缺点：

- 需要手工干预，缺乏自动 FO 机制-分布式高可用问题。
- 单机的写能力有限-分布式容量问题。
- 单机的存储能力有限-分布式容量问题。

## 一个经典的高可用场景

当一个主从集群的 主节点 失效的时候，经典的恢复步骤如下：

1. 主节点失效
2. 选出新的从节点，`slaveof no one`。
3. 先更新应用方的连接
4. 再让其他从节点换主
5. 再把恢复好的主节点作为新的从节点复制新的主节点。

3 和 4 的步骤可以互换。

## Sentinel 的高可用性

Sentinel 方案是在原生的 Master-Slave 集群之外加上一个 Sentinel 集群。

每个 Sentinel 节点会监控其他 Sentinel 节点和所有 Redis 节点。任何一个不可达的节点，它都会将其做下线标识。

如果标识的是主节点，它还会：

1 与其他 Sentinel 节点进行“协商”（negotiate），当大多数 Sentinel节点认为主节点都认为主节点不可达时。
2 会先选举出一个 leader Sentinel 节点来完成自动的 FO 工作。
3 把集群变化通知 Redis 应用方。

![此处输入图片的描述][2]

# sentinel 的部署和启动

## 单个 sentinel 节点的配置文件

```properties
# 常见参数有 4 个

# my_redis_master 是主节点的别名，redis1 是主节点的域名，当前 sentinel 起始就要监控一个 redis 节点，意味着 sentinel 的拓扑结构受 redis 集群的拓扑结构影响。3 意味着quorum是 3 ，3个节点认为 master 不可达才形成决议。
# 只有集群里的节点达到 max(quorum, num(sentinel)/2 + 1) ，选举才成立。在大多数情况下 quorum = num(sentinel)/2 + 1
sentinel monitor my_redis_master redis1 6379 3
# sentinel 会定期发送 ping 到 master（其实也包括所有其他节点），3000 毫秒不回应就意味着不可达
sentinel down-after-milliseconds my_redis_master 3000
# 集群故障转移四个阶段的任何一个步骤的失败时延，如果超过这个时间则会重新发起新故障转移
sentinel failover-timeout my_redis_master 10000
# redis 同时对从节点进行故障转移的复制的并发度
sentinel parallel-syncs my_redis_master 1

# 辅助参数
port 26379
# 写了这个文件就会导致 stdout 不再输出
logfile "sentinel.log"
# 不要乱用镜像中不存在的路径
#dir /opt/soft/redis/data
```

实际上每个 sentinel 节点的配置文件都可以写成这样，但每个文件必须单独存在，**因为 sentinel 文件会在启动时重写各自的配置文件**。

## 启动命令

```bash
redis-server /etc/redis-conf/sentinel.conf --sentinel
```

sentinel 本质上只是一种特殊的 Redis 节点。因此可以使用如下的命令查看哨兵的已知信息：

```bash
redis-cli -p 26379 info sentinel
```

sentinel 可以清楚地知道当前监控了多少个集群，集群里有多少个主从节点，一共有几个哨兵节点。

![此处输入图片的描述][3]

## 监控多个集群

一套 Sentinel 可以监控多个 Redis 集群，只要准备多套`sentinel monitor my_redis_master redis1 6379 3`里的 master name my_redis_master 即可。

## 配置调整

```bash
sentinel set xxx xxx
```

需要注意：

 1. sentinel set 只对当前节点有效。
 2. sentinel set 命令执行完成以后会立即刷新配置文件，这点和普通节点需要使用`config rewrite`。
 3. 所有节点的配置应该一致。
 4. sentinel 堆外不支持 config 命令

## 部署技巧

 1. sentinel 节点应该在物理机层面做隔离。
 2. sentinel 集群应该有超过 3 个的奇数节点。
 3. 奇数节点对选举的效果是最优的。
 4. 可以一套 sentinel 监控多套集群，也可以多套 sentinel 监控多套集群。取舍的时候需要考虑的是：是否 sentinel 节点自身的失败需要被隔离。
 
## API

```bash
# 在 cli 内
sentinel masters
sentinel master master-name
sentinel slaves slave-name

# 强制失效转移
sentinel failover master-name

# 校验 quorum 是否稳定
sentinel ckquorum master-name

# 配置刷盘
sentinel flushconfig

# 取消 sentinel 对集群的监控
sentinel remove master-name

# 增加 sentinel 对集群的监控
sentinel monitor <master-name> <host> <port> <quorum>
```

# 实现原理

## 三个定时任务

- 每隔 10s，sentinel 往所有 M/S 发 info 获取最新的拓扑结构
 -从主节点可以实时获知从节点的信息

![info 任务.png](info 任务.png)

- 每隔 2s，sentinel 节点会向 Redis 数据节点的 _sentinel_:hello 频道上发送改 Sentinel 节点对主节点的判断，以及当前 Sentinel 节点的信息。同时每隔 Sentinel 节点也会订阅该频道，来了解其他 Sentinel 节点以及它们对主节点的判断。
 - sentinel 可以通过这个频道获取 sentinel 之间的信息
 - 交换主节点的状态，可以作为后续**客观下线**和领导者选举操作的依据：

![发布意见任务.png](发布意见任务.png)

- 每隔 1s，sentinel 会向M/S和其他 Sentinel 发送一条 ping 命令做一次心跳检测，来确认节点是否可达。

![ping 任务.png](ping 任务.png)

## 主观下线和客观下线

### 主观下线

任意sentinel ping master 超时（sentinel down-after-milliseconds my_redis_master 3000），就可以单节点认为该节点已失败。

### 客观下线

sentinel 一进入主观下线状态，就会发送 sentinel is-master-down-by-addr 命令询问其他哨兵节点**直接询问**它们对主节点的判断，当超过<quorum>的个数，Sentinel 节点认为主节点确实有问题，这时候 Sentinel 就可以客观下线的决定。

[1]: https://s2.ax1x.com/2019/10/19/KmgbkD.png
[2]: https://s2.ax1x.com/2019/10/19/KmW2tS.jpg
[3]: https://s2.ax1x.com/2019/10/27/KysZ79.png

