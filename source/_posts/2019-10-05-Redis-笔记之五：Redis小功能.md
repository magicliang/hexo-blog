---
title: Redis 笔记之五：Redis小功能
date: 2019-10-05 16:31:59
tags:
- Redis
---
# 慢查询

## 命令执行的典型过程

 1. 发送命令
 2. 命令排队
 3. 命令执行
 4. 返回结果

慢查询值统计 step3 的执行时间，**即使没有慢查询，客户端也可能超时**。
  
## 阈值参数

相关的阈值参数分别为：slowlog-log-slower-than和slowlog-max-len。

```bash
# 设置超时时间为10000微妙。设置为0则记录所有查询，设置为-1则不记录任何信息
config set slowlog-log-slower-than 10000

# 设置记录慢查询的记录集大小。这个集采用先进先出的淘汰逻辑
config set slowlog-max-len 1000

# 获取所有慢日志
SLOWLOG get

# 获取时间上最近的一条慢日志
SLOWLOG get 1

# 获取所有慢查询数量
SLOWLOG len

# 重置慢查询日志列表
SLOWLOG reset
```

## 查询结果

> 1) 1) (integer) 7
   2) (integer) 1570264725
   3) (integer) 7
   4) 1) "SLOWLOG"
      2) "get"
      3) "0"
   5) "127.0.0.1:49802"
   6) ""

慢日志的格式为：
1 慢日志id
2 日志发生的时间戳
3 命令耗时
4 命令详情
5 客户端地址
6 客户端的名称

参考：https://redis.io/commands/slowlog

## 最佳实践

1 调大 slowlog-log-slower-than 到1毫秒左右，可以保证 1000 的QPS（实际上在单台 mac pro上的 rps 可以达到接近10万）。
2 调大 slowlog-max-len，并定期把其中的数据取出来存入其他存储层。
3 如果发生客户端超时，注意对照相应的时间点，注意查看是不是存在慢查询导致级联失败。

# Redis Shell

## redis-cli 

```bash
# 重复执行命令3次
redis-cli -r 3 ping

# 重复每隔1秒执行命令5次
redis-cli -r 5 -i 1 ping

# 重复每隔10毫秒执行命令5次
redis-cli -r 5 -i 0.01 ping

# 定时输出内存使用状况
redis-cli -r 100 -i 1 info | grep used_memory_human

# 从 stdin 读取数据作为 redis-cli 的最后一个参数
echo "world" | redis-cli -x set hello

# -c 在 Redis Cluster节点中使用

# -a 使用auth，可以不用手动输入 auth 命令

# --scan --pattern 扫描指定模式的键，相当于使用 scan 命令

# --slave 把当前客户端模拟成当前Redis节点的从节点，可以用来获取当前 Redis节点的更新操作。基本相当于一个全量的事件监听消费者（又像 wireshark）。

#  --rdb 可以强制当前系统执行一次 dump 到 rdb 中的操作。
redis-cli --rdb dump1.rdb

# 性能调优的时候很有用，会输出现有节点里最大的 key 的统计数据
redis-cli --bigkeys

# --pipe 把命令封装成 Redis通信协议定义的数据格式。
cat pipeline.txt | redis-cli --pipe

# 对 lua 脚本求值，注意和 pipe 区别。它消费的内容是lua脚本，pipe消费的脚本是 redis 命令
redis-cli --eval

# 对网络延迟进行采样
redis-cli --latency
redis-cli --latency-history
redis-cli --latency-dist

# 输出实时统计数据，类似 info 命令
redis-cli --stat

# --no-raw 返回原始格式（可以看到编码、格式化以前的字符，不可见字符），--raw返回格式化后的格式（human readable，看不见不可见字符）
redis-cli --no-raw get hello
redis-cli --raw get hello
```

## redis-server

```bash
# 测试当前系统是否能提供 1024 M 字节（1G）的内存
redis-server --test-memory 1024
```

## redis-benchmark

```bash
# 100个客户端同时请求redis，一共请求20000次，随机插入10000个键，每个请求携带3个 pipeline，以 csv 格式输出测试结果
redis-benchmark -c 100 -n 20000 -r 10000 -P 3 --csv

# 只测试 get set 命令
redis-benchmark -t get set

# 只输出 requests per second 相关信息
redis-benchmark -q
```

# pipeline

如上所述，Redis 命令执行流程是：

1. 发送命令
2. 命令排队
3. 命令执行
4. 返回结果

1+4 的耗时统称为RTT（Round Trip Time，往返时间）。

当我们把多个命令合并到一个 RTT 里的时候，可以使用 pipeline。

原生批量命令和 pipeline 的差异是：

1. 原生批量命令是原子的，pipeline 是非原子的。
2. 原生批量命令是一种操作针对多个 key，而 pipeline 是更高层的组合，一个流水线组合多个批量命令。
3. 原生批量命令只靠 Redis 服务端即可实现，pipeline 需要服务端和客户端共同实现。

# 事务

Redis 支持简单的事务（multi-exec）以及 lua 脚本。

## 简单事务（multi-exec）

一个基本的例子
```bash
multi
sadd user:a:follow user:b
sadd user:b:fans user:a
# 在提交以前，所有的命令都会被 queued 住，提交以后会批量返回批量执行结果
exec

# 在事务提交以后，其他 cli 才能读到最新的结果。被 queued 不算真的执行过
sismember user:b:fans user:a:follow
```
放弃提交（而不是回滚）的例子：
```bash
multi
incr num1
discard
```
被 queue 的命令因为被抛弃所以没有被执行。

除此之外，**如果命令本身有语法错误，如把 set 写成了 sset，可以在 queue 的时候被检测出来，则事务整体都不会被执行。**我们只能得到 EXECABORT 错误。

```bash
multi
incrs num1
exec
```

但是，**如果命令本身有运行时错误，比如对错误类型的value 进行了错误的操作（对 list 执行了 zadd 操作），则已经执行成功的命令是不会被回滚的！**

```bash
multi
del user:a:follow user:b:fans
# 这两条命令可以执行成功
sadd user:a:follow user:b
sadd user:b:fans user:a
# 这一条则不可以
zadd user:b:fans 1 user:a
exec
```

上面的操作本身会部分操作成功。可见 Redis 虽然声称这个特性是一个 transacion，但并不具备标准的数据库事务的原子性。

## 乐观锁

在 Redis 中使用 watch 命令可以决定事务是执行还是回滚。一般而言，可以在 multi 命令之前使用 watch 命令监控某些键值对，然后使用 multi 命令开启事务，执行各类对数据结构进行操作的命令，这个时候这些命令就会进入队列。

当 Redis 使用 exec 命令执行事务的时候，它首先会去比对被 watch 命令所监控的键值对，如果没有发生变化，那么它会执行事务队列中的命令，提交事务；如果发生变化，那么它不会执行任何事务中的命令，操作结果就是  nil。

![此处输入图片的描述][1]

```bash
set key java
# watch 在单一的操作流水里应该放在 multi 以前
watch key
multi
append key jedis
exec
get key

# 另一个 redis-cli 如果同步操作这个 key，上面的 exec 就会返回 nil
append key python
```

我们也可以使用事务来获取多重结果：
```bash
multi
get hello
get hello
exec
```

## Lua

Redis 提供 eval 和 evalsha 两种方法来调用 Lua 脚本。

lua 脚本拥有以下优点：

1. 可以提供原子执行的能力，执行过程中不会插入其他命令。
2. 可以提供自定义命令的能力。
3. 可以提供命令复用的能力。

我们可以自由建模，然后打包一个组合脚本进行组合之间的运算-所以可以 组合使用各种原子 API 来实现复杂计算。

### eval

```bash
# 脚本里的 1 指的是 keys 列表的长度，然后我们会跟上一个长度为 1 的 keys 列表（1 就是用来分割参数列表用的），接下来的参数都 arguments。
eval 'return ""..KEYS[1]..ARGV[1]' 1 redis world

# 分布式锁解锁的例子。注意单引号和双引号的区别。KEYS 和 ARGV 数组的区别。
eval "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end" 1 hello world


# 调用 redis 内置命令
eval 'redis.call("set", "hello", "java123")' 0
```
call 如果遇到错误，则脚本执行会返回错误。如果需要忽略错误执行，需要使用 pcall。

除了 redis.call 以外，还可以使用 redis.log 来把日志打印到 redis 的日志文件里，但要注意日志级别。

如果脚本比较长，可以考虑使用外部文件，配合 --eval 选项来执行。

Redis 的高版本里自带 [lua debuger][2]。

### evalsha

这个功能可以实现 lua script 的复用，其基本流程为：
1. 将 lua 脚本加载到服务器端，得到脚本的 sha1 指纹。
2. evalsha 可以使用 sha1 指纹来复用脚本，避免重复发送脚本到服务器端的开销。

```bash
redis-cli script load "$(cat lua_get.lua)"
xcdfdfggsgf
evalsha xcdfdfggsgf 1 hello world
```

### 管理 lua 脚本

```bash

# 加载脚本
script load "$(cat lua_get.lua)"

# 确认 sha1 是否存在
script exists xdfg

# 清理所有的脚本，一切加载过的脚本都不存在
script flush

# 无参数，直接杀掉当前正在阻塞 redis server instance 的脚本。但如果这个脚本正在执行 write commands，这个命令无法成功执行。这时候只能使用 shutdown 来关掉 redis 服务器。
script kill
```

# 位图

详细的用法见[位操作命令][3]。

它的用例比较有意思，一个典型的用例是，统计一个大型社交网站的所有成员的具体登录信息。我们可以统计每天都产生了多少登录，最小的登录 id 是什么，最大的登录 id 是什么。但位图也不是万能的，如果位图很稀疏，则不如转为一个 list 或者 set 会更省内存-这需要做内存测试。

# HyperLogLog

HyperLogLog 并不是新的数据结构，而是字符串与基数算法（cardinality algorithm）的结合。

```bash
# 往一个 key 里增加值，即 string 也可以当做复合值使用。这些值不能重复，特性上与 set 和 sorted set 一样。
pfadd 2016_03_06:unique:ids u1 u2 u3

# raw
object encoding 2016_03_06:unique:ids

# string
type 2016_03_06:unique:ids
 
# HYLL\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x80d\xb1\x84M\xbb\x88M\x8e
get 2016_03_06:unique:ids

# 计算集合总数
pfcount 2016_03_06:unique:ids
```

HyperLogLog 本身极省内存，但数据量变大后，pfcount 会变得不准，最多有 0.81%的失误率。

```bash
pfadd 2016_03_07:unique:ids u1 u2 u3 u4

# 合并集合
pfmerge 2016_03_06-07:unique:ids 2016_03_06:unique:ids 2016_03_07:unique:ids
```

HyperLogLog 具有以下特点：

1. 不能取出存入数据。
2. 计数不准，近似准确。
3. 极省内存。


在现实之中，bitmap、HyperLogLog和传统的 set 可以视场景交替使用或者配合使用。比如 bitmap 标识哪些用户活跃，hyperloglog计数。

# 发布（publish）/订阅（subscribe）



```bash
```


  [1]: https://s2.ax1x.com/2019/10/05/uy8EPU.png
  [2]: https://redis.io/topics/ldb
  [3]: https://magicliang.github.io/2019/07/22/Redis-%E7%AC%94%E8%AE%B0%E4%B9%8B%E5%9B%9B%EF%BC%9A%E5%B8%B8%E7%94%A8%E5%91%BD%E4%BB%A4/#%E4%BD%8D%E6%93%8D%E4%BD%9C%E5%91%BD%E4%BB%A4