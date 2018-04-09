---
title: Hyperledger Fabric MSP 相关问题
date: 2018-03-15 16:29:15
tags:
- Hyperledger Fabric
- 区块链
---
Fabric要求所有的 paticipant 有相关的 identity。identity是由x509证书认证的（大致上也就是各种signcert），每个 identity 有自己的 principal，包含了大量的 property，包括但不仅限于组织名。

PKI 生成 identity，而 MSP 表达治理组织的规则，包括哪些 identity 属于哪些组织，且参与网络中。

## PKI

PKI 是一种标准，一般由四个元素组成：

- Digital Certificates
- Public and Private Keys
- Certificate Authorities
- Certificate Revocation Lists

### 数字证书

一个持有一个组织的系列属性的数字文件。常见的数字证书是X509标准的，很像一个国家发放的身份证（有名称，省份，国家，还有组织的名字）。

>  For example, John Doe of Accounting division in FOO Corporation in Detroit, Michigan might have a digital certificate with a SUBJECT attribute of C=US, ST=Michigan, L=Detroit, O=FOO Corporation, OU=Accounting, CN=John Doe /UID=123456. 

注意，这些属性都是这个party的subject attribute的一部分。

![](https://ws1.sinaimg.cn/large/66dd581fly1fq5dzlg12gj20ku09pwfu.jpg)

注意看，这个 party 的公钥是这个证书的一部分，而私钥则不是。

因为有密码学加持，所以这个证书是抗篡改的，里面的attribute可以被认为是真的，只要别人信任这个证书的签发方的话。因为这个签发方用自己的私钥的方法把这些 attribute 加密写入（secrete writing）了这个证书。注意，签发证书的时候，csr的请求者不需要提供自己的私钥。在CA那里，是证书公钥 + CA 私钥 + CA 证书（当然也包含了CA的公钥）来生成新的证书。

### 质询和公私钥

质询和消息完整性是安全通信的重要概念。

私钥签名，公钥验证签名。

### CA 

现实中的CA是一系列权威。

用自己的私钥给一个party的属性和公钥签名。因为CA是周知的权威，它的签名可以被周知的CA公钥验证。

在区块链里，我们当然希望一个或多个CA可以帮我们定义一个组织里有哪几个成员。

因为根CA的证书，可以帮我们验证某个证书是不是它签发的，所以我们可以通过根CA签发一个中间CA的证书，而这个中间CA一旦被验证了，它也可以产生它签发的证书。这就是CA构成的信任链的本质了。

换言之，任何一个证书，都可以拿来当CA证书来用。

![](https://ws1.sinaimg.cn/large/66dd581fly1fq5er6jmd7j20iu0amwfh.jpg)

做区块链世界里，理论上不同的组织可以由不同的根 CA 签发证书。

Fabric 的 CA 不能拿来提供 SSL 证书，这点来看就不如 openssl 这样的工具了。而且，实际上我们也可以使用公共的权威 CA 来生成相关的组织证书。

CA 有证书撤销列表（Certificate Revocation Lists），验证的party要验证证书的时候，还要查看撤销列表（在线查看？离线怎么办？）：

![](https://ws1.sinaimg.cn/large/66dd581fly1fq5f2fzrcpj20rc0aojs9.jpg)

## MSP

### 1.1 文档

MSP 的工作方式无非有两个：
- 列出一个组织里所有的成员。
- 列出一个CA，声称由这个CA签发的证书都是这个组织的成员。

MSP的实际作用还超过于此，它还规定了很多角色和特权的细节，如果admin，普通user，reader和writer（后面这两项是由某些policy决定的）。

按照1.1的文档，现在Fabric提倡一个组织（这里的组织不同于x.509标准里的组织）使用一个MSP（这也符合gossip协议的要求）。比如ORG1-MSP之于ORG1，特殊情况下才需要ORG2-MSP-NATIONAL和ORG2-MSP-GOVERNMENT之于ORG2。

![](https://ws1.sinaimg.cn/large/66dd581fly1fq5hqb85d1j20r80blabu.jpg)

如上图可以看出，合理的MSP总是由不同的根CA经过若干个ICA单独生成的。

每个组织还可以再分成不同的 OU（organizaional units），用不同的 OU 来区分不同的业务线。这个OU就是 X.509 证书里的那个 atrribute。我们可以靠 OU 这个属性来做权限控制（实际上我们应该可以通过任何属性来做权限控制）。Fabric的原话是，我们可以用同一套 CA 体系，靠不同的 OU 来区分不同的组织成员（为什么不直接用不同的 O ？）。

MSP可以分为两类，频道MSP（频道配置文件）和本地MSP（节点或者user的msp文件夹是必须存在的）。这两种MSP定义了outside channel level和 channel level 的管理和参与权利。因为频道MSP包含了这个 channel 的组织成员配置，只有这些配置里包含进了这些**组织的 MSP**，这些组织才能参与到频道中。其关系图如下：

![](https://ws1.sinaimg.cn/large/66dd581fly1fq6f9vspyoj21180frdjh.jpg)

似乎频道MSP会被拷贝到各个peer的本地。这样的话是不是网络中的MSP变动（加入新的组织）的时候要动态地滚动重启整个网络呢？

高级的MSP（频道）管理网络资源，包括加入联盟等问题，低级（本地）MSP管理本地资源，包括这本地部署合约初始化合约等问题。

此外，MSP还可以分为 Network MSP，Channel MSP，Peer MSP，Orderer MSP。

MSP的组成部分无外乎，所以MSP实际上是一大堆文件夹组成的东西：

![](https://ws1.sinaimg.cn/large/66dd581fly1fq6fwuslcuj20na09jgmk.jpg)

现实中的结构有：

![](https://ws1.sinaimg.cn/large/66dd581fly1fq6g83ks5cj20kc10awit.jpg)

这里没有把user也列出来，基本上除了本节点或者user私有的证书（包含了公钥）和keystore（包含了私钥）以外，有大量的ca证书，管理员证书和tls证书是整个org共享的。注意，不同组织的ca证书是完全不同的，足以证明cryptogen这个工具生成的不同的组织的组织根ca还是不一样的。



### 1.0 文档

MSP 把**签发和验证证书**、**用户质询**（换言之MSP即使是在peer/client上也提供authentication的功能）的过程给抽象化了。MSP 可以完全定制化实体（identity）的记号，和这些实体被治理的规则。实际上对 Peer 而言，MSP 就是他们的一部分，可以被认为是会员相关操作的一部分。

一个 Fabric 区块链可以被一个或多个 MSP 统治。这提供了会员制操作的模块化，和不同会员制标准的互操作性。

在 Fabric 中，签名验证（signature verification）是 authentication。

每一个 peer 和 orderer 都需要局部设置 MSP 配置（实际上就是需要配置**证书和 signing keys**）。每个 MSP 必须有个 MSP ID 来引用这个 MSP。实际上如果我们仔细观察 crypto-config 这个文件夹，就会发现组织域、peer、admin 和一般 user，凡是有 identity 的，都有 msp 的配置。而 MSP 的全套配置必然包括：

- admincerts
- cacerts
- tlscacerts

如果可以发起和验证签名，还需要有：

- keystore 这个文件似乎不是私钥本身，而是私钥的集合大概是这种形式的：
```
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg3dCRAHW1PFdllpwe
9/KnhNopUClPY1FFB5cDNZbTzzyhRANCAAShU8bpfce3KuaVSlR3aqS/YowoiKAd
xFQgtR/IIb6+xEqTCcVFdS/qJF+HS1JlhaDqyMYfJC+C/FqudHeIBIae
-----END PRIVATE KEY-----
```
- signcerts

用户可以使用 Openssl（这个大概是没人用的）、cryptogen 和[Hyperledger Fabric CA][1]来生成用来配置 MSP 的**证书和 signing keys**。

在每个节点的配置文件里面（对 peer 节点是 core.yaml 对orderer 节点则是 orderer.yaml）指定 mspconfig 文件夹的路径和节点的 MSP 的 ID。mspconfig 文件夹的路径必须是相对于`FABRIC_CFG_PATH`的路径，在 peer 上用`mspConfigPath`参数表示，在 orderer 上用`LocalMSPDir`参数表示。MSP ID 在 peer 上用`localMspId`表示，在 orderer 上用`LocalMSPID`表示（注意大小写不同）。这些参数可以被环境变量给覆写掉，对于 peer 用`CORE_PEER_LOCALMSPID`，对于 orderer 用`ORDERER_GENERAL_LOCALMSPID`。当 orderer 启动了以后，必须把“系统 channel”的创世区块提供给 orderer。

只有手动操作才能重新配置一个“本地”MSP，而且要求那个 peer 或者 orderer 进程重启。未来可能会提供在线动态的重配置。

在 mspconfig 文件夹下可以用一个 config.yaml 文件来定义组织化单元。大概是这样：

```yaml
OrganizationalUnitIdentifiers:
  - Certificate: "cacerts/cacert1.pem"
    OrganizationalUnitIdentifier: "commercial"
  - Certificate: "cacerts/cacert2.pem"
    OrganizationalUnitIdentifier: "administrators"
```

这些 ou 的定义是可选的，是为了在组织内再进一步按照业务线分权。默认的情况下没有的话，组织里的 identity 就不再进一步分权。

有一种特殊的分类方法，把签发事务、查询 peer 的 identity 称作 client，而把背书和提交事务的节点被称作 peer。问题是默认的情况下一个 peer 容器就是 peer 了，也不需要专门的 config 来配置。所以我想应该只是专门使用 client 来区分、鉴别 identity。

```yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: "cacerts/cacert.pem"
    # 不同的 OUIdentifier 都需要这个字段。MSP 的 administrator 还必须是 client
    OrganizationalUnitIdentifier: "client"
  PeerOUIdentifier:
    Certificate: "cacerts/cacert.pem"

    OrganizationalUnitIdentifier: "peer"
```

正如我们前面看到的，orderer 在启动的时候，需要得到一个“系统频道”的创世区块，这个创世区块必须包含全网络中出现的所有 MSP 的验证参数。这些验证参数包括：“verification parameters consist of the MSP identifier, the root of trust certificates, intermediate CA and admin certificates, as well as OU specifications and CRLs”。
这样 orderer 才能处理频道创建请求（channel creation requests）。

而对于应用程序频道而言，只有治理那个频道的 MSP 的验证组件必须被包含在那个频道的创世区块中。在 peer 加入频道以前，应用程序有义务把正确的 MSP 配置信息包含在创世区块之中。

要修改一个频道里的 MSP，要一个有那个频道 administrator 证书的拥有者，创建一个`config_update`对象，然后把这个对象在频道里公布。**这是通过 configuration block 来实现的吗？**

网络中还可能存在大量的 intermediate CAs。

MSP 的最佳实践有：

- 一个组织拥有多个 MSP。
    
这是一个组织下面有多个分支机构的时候才会用到的设计方法。

- 多个组织共用一个 MSP。

什么情况下会让一个联盟中的多个组织共用一个 MSP 呢？除非它们极为相似吧。

- client 要和 peers 分开。怎么做到的呢？

- 要有独立的 admin 和 CA 证书。

- 把中间 CA 放到黑名单里面。

- CA 和 TLS CA 放在不同的文件夹下。

  [1]: http://hyperledger-fabric-ca.readthedocs.io/en/latest/