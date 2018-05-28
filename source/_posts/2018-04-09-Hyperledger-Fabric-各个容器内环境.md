---
title: Hyperledger Fabric 各个容器内环境
date: 2018-04-09 14:53:18
tags:
- Hyperledger Fabric
- 区块链
---
## peer 容器

### /opt/gopath/src/github.com/hyperledger/fabric/peer

虽然是WORKING_DIR，什么都没有。这个目录是/bin/bash永远的进入路径，不管在哪个目录退出，重新进入还是会进入这个路径。

### /etc/hyperledger/fabric 

```bash
# 原生的三个配置文件。所以修改peer的行为要通过环境变量来修改，让docker用COMMAND启动peer进程的时候吸收这几个配置文件和环境变量
core.yaml

# 这两个文件似乎不关peer的事情
configtx.yaml
orderer.yaml
# 这两个文件夹要被外部的数据卷映射修改过来，实际上只能依赖于外部
# 这个文件夹本质上还是 core.yaml 默认的 mspConfigPath 的值
msp
tls
```

### /var/hyperledger/production

这个文件夹存放unix系统里面的动态程序数据。

```bash
# 它下面有打包好的CIP（chaincode install package）格式的链码 chaincodes/mycc.1.0。
chaincodes
# 这个文件夹就特别像以太坊的datadir了。
ledgersData
# 因为这是系统中唯一的进程，所以它的进程号是1，是不是docker内的主进程都是这样？
peer.pid
```

### 启动命令

整个容器内只有一个进程`peer node start`。完全没有其他命令行参数，所以就是靠环境变量来支持。

这个启动命令被安装只`/usr/local/bin/`下，里面只有这个命令（精简的ubuntu系统）。

### 全部环境变量

用`env`命令可以打出来：

```
HOSTNAME=fba1d49eb609
TERM=xterm
CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
# 省略 LS_COLORS
CORE_PEER_PROFILE_ENABLED=true
CORE_PEER_GOSSIP_ORGLEADER=false
CORE_PEER_LOCALMSPID=Org3-MSP
CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PWD=/var/hyperledger/production
CORE_PEER_TLS_ENABLED=true
CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_byfn
CORE_PEER_ID=peer0.ORG3_DOMAIN
SHLVL=1
HOME=/root
CORE_LOGGING_LEVEL=DEBUG
CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.ORG3_DOMAIN:7051
FABRIC_CFG_PATH=/etc/hyperledger/fabric
CORE_PEER_ADDRESS=peer0.ORG3_DOMAIN:7051
CORE_PEER_GOSSIP_USELEADERELECTION=true
CORE_PEER_GOSSIP_BOOTSTRAP=peer0.ORG3_DOMAIN:7051
_=/usr/bin/env
OLDPWD=/etc/hyperledger/fabric
```

## orderer 容器

### /opt/gopath/src/github.com/hyperledger/fabric

虽然是WORKING_DIR，什么都没有。这个目录是/bin/bash永远的进入路径，不管在哪个目录退出，重新进入还是会进入这个路径。

注意，这个目录没有peer子目录。

### /etc/hyperledger/fabric 

```bash
# 同 peer 容器
core.yaml
configtx.yaml
orderer.yaml
# 没有tls文件夹
# 这里的msp似乎没什么用，var下的msp才是有用的。
msp
```

### /var/hyperledger/

这个文件夹下有专门的两个子文件夹。

```
# peer 容器没有单独的peer文件夹，直接就是production
orderer  
production
```

orderer 文件夹下有三个文件：

```
# 这个创世区块是外部映射进来的。
orderer.genesis.block
# 这两个文件夹也是外部映射进来的，却不是映射到etc而是映射到这里，不知道为什么
msp  
tls
```

production 文件夹下还有一个orderer文件夹：

```
# 类似peer存放链数据了，但peer又没有一个单独的production/peer文件夹
chains
index

# 没有 orderer 的pid
```

### 启动命令

orderer 连启动参数都没有。直接启动就会遇到地址被占用的错误。

这个启动命令被安装只`/usr/local/bin/`下，里面只有这个命令（精简的ubuntu系统）。

### 全部环境变量

```
# 专门指定了本地 msp 目录。
ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
HOSTNAME=bf4847ae1253
ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.genesis.block
TERM=xterm
# 省略 LS_COLORS
ORDERER_GENERAL_LOCALMSPID=OrdererMSP
ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PWD=/opt/gopath/src/github.com/hyperledger/fabric
ORDERER_GENERAL_LOGLEVEL=debug
ORDERER_GENERAL_GENESISMETHOD=file
ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
SHLVL=1
HOME=/root
FABRIC_CFG_PATH=/etc/hyperledger/fabric
ORDERER_GENERAL_TLS_ENABLED=true
_=/usr/bin/env
```

## cli 容器

### /opt/gopath/src/github.com/hyperledger/fabric/peer

cli容器的这个工作目录倒是有很多文件了：

```
# 重定向到控制台
log.txt
# 这个频道的channel创世区块，应该是在这个工作目录下由 createChannel() 函数创建出来的
mychannel.block
# 这3个文件夹就是从外部映射进来的
# 这个文件夹在这个相对路径下，就可以让peer channel 来生成新的频道
channel-artifacts
crypto
scripts
```

### /opt/gopath/src/github.com/hyperledger/fabric/examples

cli 容器独有的放置链码的文件夹，也是外部的docker映射进来的。

### /etc/hyperledger/fabric

这个文件夹可以说也是从标准环境中诞生出来的（标准镜像里就有这些文件夹了么？）

```
configtx.yaml  
core.yaml
# 也没人映射进来
msp
orderer.yaml
```

### /var/hyperledger/

没有任何内容，没有production数据需要单独存放。

### 环境变量

```
HOSTNAME=cf5db270ec10
TERM=xterm
CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG1_DOMAIN/peers/peer0.ORG1_DOMAIN/tls/ca.crt
CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG1_DOMAIN/peers/peer0.ORG1_DOMAIN/tls/server.key
# 省略 LS_COLORS
CORE_PEER_LOCALMSPID=Org1MSP
CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG1_DOMAIN/peers/peer0.ORG1_DOMAIN/tls/server.crt
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/go/bin:/opt/gopath/bin
PWD=/opt/gopath/src/github.com/hyperledger/fabric/peer
CORE_PEER_TLS_ENABLED=true
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG1_DOMAIN/users/Admin@ORG1_DOMAIN/msp
CORE_PEER_ID=cli
SHLVL=1
HOME=/root
GOROOT=/opt/go
CORE_LOGGING_LEVEL=DEBUG
FABRIC_CFG_PATH=/etc/hyperledger/fabric
CORE_PEER_ADDRESS=peer0.ORG1_DOMAIN:7051
LESSOPEN=| /usr/bin/lesspipe %s
GOPATH=/opt/gopath
LESSCLOSE=/usr/bin/lesspipe %s %s
_=/usr/bin/env
```

## 链码容器

### /etc/hyperledger/fabric/

只有一个peer.crt文件，应该是在生成这个镜像的时候，从特定的peer上拷贝过来的。

没有/opt下的gopath，也没有/var下的production目录。

### 启动命令

只有一个启动命令

```
"Path": "chaincode",
"Args": [
    "-peer.address=peer1.ORG3_DOMAIN:7051"
],
```

`/usr/local/bin/`下只安装了一个命令`chaincode`。

### 环境变量

```
HOSTNAME=a2886170947f
TERM=xterm
CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/peer.crt
# 省略 LS_COLORS
CORE_CHAINCODE_ID_NAME=mycc:1.0
CORE_CHAINCODE_LOGGING_LEVEL=info
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PWD=/
CORE_PEER_TLS_ENABLED=true
CORE_CHAINCODE_BUILDLEVEL=1.0.6
CORE_CHAINCODE_LOGGING_FORMAT=%{color}%{time:2006-01-02 15:04:05.000 MST} [%{module}] %{shortfunc} -> %{level:.4s} %{id:03x}%{color:reset} %{message}
SHLVL=1
HOME=/root
CORE_CHAINCODE_LOGGING_SHIM=warning
_=/usr/bin/env
```