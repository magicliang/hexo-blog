---
title: Hyperledger Fabric 的配置文件解读
date: 2018-03-15 14:38:14
tags:
- Hyperledger Fabric
- 区块链
---
## Crypto Generator

x.509 相关的文件主要包含两个东西：证书和 signing keys。

cryptogen 使用的配置文件是`crypto-config.yaml`。

x.509 的根证书是`ca-cert`。它把 peers 和 orderers 绑定到一个 Org 里面。在这个网络里，每个组织都有签发自己的证书的能力，可以用这个 ca 来签发其他证书给节点和 client。

签发交易用的是私钥（keystore），验证交易用的是公钥（signcerts）。

```yaml
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# ---------------------------------------------------------------------------
# "OrdererOrgs" - Definition of organizations managing orderer nodes
# ---------------------------------------------------------------------------
OrdererOrgs:
  # ---------------------------------------------------------------------------
  # Orderer
  # ---------------------------------------------------------------------------
  # 这里的 Name 是 MemberShip 的 ID，大致就是一个法律实体作为会员。
  - Name: Orderer
    Domain: ORDERER_DOMAIN
    # ---------------------------------------------------------------------------
    # "Specs" - See PeerOrgs below for complete description
    # ---------------------------------------------------------------------------
    Specs:
      # orderer docker 容器的名字 
      - Hostname: orderer
# ---------------------------------------------------------------------------
# "PeerOrgs" - Definition of organizations managing peer nodes
# ---------------------------------------------------------------------------
PeerOrgs:
  # ---------------------------------------------------------------------------
  # Org1
  # ---------------------------------------------------------------------------
  - Name: Org1
      # 组织1的完整 domain
    Domain: ORG1_DOMAIN
    # ---------------------------------------------------------------------------
    # "Specs"
    # ---------------------------------------------------------------------------
    # Uncomment this section to enable the explicit definition of hosts in your
    # configuration.  Most users will want to use Template, below
    #
    # Specs is an array of Spec entries.  Each Spec entry consists of two fields:
    #   - Hostname:   (Required) The desired hostname, sans the domain.
    #   - CommonName: (Optional) Specifies the template or explicit override for
    #                 the CN.  By default, this is the template:
    #
    #                              "{{.Hostname}}.{{.Domain}}"
    #                 这个 CommonName 搞不好是拼出来的完整容器名，比如peer0.org1.com 之类的。
    #
    #                 which obtains its values from the Spec.Hostname and
    #                 Org.Domain, respectively.
    # ---------------------------------------------------------------------------
    # Specs:
    #   - Hostname: foo # implicitly "foo.ORG1_DOMAIN"
    #     CommonName: foo27.org5.example.com # overrides Hostname-based FQDN set above
    #   - Hostname: bar
    #   - Hostname: baz
    # ---------------------------------------------------------------------------
    # "Template"
    # ---------------------------------------------------------------------------
    # Allows for the definition of 1 or more hosts that are created sequentially
    # from a template. By default, this looks like "peer%d" from 0 to Count-1.
    # You may override the number of nodes (Count), the starting index (Start)
    # or the template used to construct the name (Hostname).
    #
    # Note: Template and Specs are not mutually exclusive.  You may define both
    # sections and the aggregate nodes will be created for you.  Take care with
    # name collisions
    # ---------------------------------------------------------------------------
    # 这里的容器名就不是用 Hostname 指定出来的，而是用 spec 推导出来的了。具体还是看文档，这里就是规定这个组织里有多少个 peer，peer 用什么名字。现在这个名字就是 peer0，peer1 的形式。当然都可以改。
    Template:
      Count: 2
      # Start: 5
      # Hostname: {{.Prefix}}{{.Index}} # default
    # ---------------------------------------------------------------------------
    # "Users"
    # ---------------------------------------------------------------------------
    # Count: The number of user accounts _in addition_ to Admin
    # ---------------------------------------------------------------------------
    # 这个users 本身就是指的非 admin 的 user 要创建出多少套 identity 证书来。
    Users:
      Count: 1
  # ---------------------------------------------------------------------------
  # Org2: See "Org1" for full specification
  # ---------------------------------------------------------------------------
  - Name: Org2
    Domain: ORG2_DOMAIN
    Template:
      Count: 2
    Users:
      Count: 1
  - Name: Org3
    Domain: ORG3_DOMAIN
    Template:
      Count: 2
    Users:
      Count: 1

```

跑完这个工具生成的材料都在`crypto-config`这个文件夹下，它总会归属于 ordererOrganzations 和 peerOrganizations。这两个文件夹下的子文件夹就是由拓扑决定的几个域文件夹。每个域下必有 ca、msp、peers/orderers、tlsca 和 users 五个文件夹。每个user，peer和orderer还必然有自己的MSP。

## configtxgen 相关

`configtxgen`需要使用的配置文件是`configtx.yaml`，解说文件大致如下：

```yaml
---
################################################################################
#
#   Profile
#
#   - Different configuration profiles may be encoded here to be specified
#   as parameters to the configtxgen tool
#
################################################################################

# 在这里不同的 profile 可以让 configtxgen 作为命令行参数来读取
Profiles:
    # 这就是 profile 的名字
    # 针对创世区块的 profile
    TwoOrgsOrdererGenesis:
        Orderer:
            # 按照 YAML 的语法，这是对 anchor 的引用
            <<: *OrdererDefaults
            Organizations:
                # 这里引用了下面的 &OrdererOrg
                - *OrdererOrg
        Consortiums:
            SampleConsortium:
                Organizations:
                    # 这里引用了下面的 &Org1
                    - *Org1
                    - *Org2
    # 针对 channel 的 profile
    TwoOrgsChannel:
        # 引用了同一个联盟
        Consortium: SampleConsortium
        Application:
            <<: *ApplicationDefaults
            Organizations:
                - *Org1
                - *Org2

################################################################################
#
#   Section: Organizations
#
#   - This section defines the different organizational identities which will
#   be referenced later in the configuration.
#
################################################################################
Organizations:

    # SampleOrg defines an MSP using the sampleconfig.  It should never be used
    # in production but may be used as a template for other definitions
    - &OrdererOrg
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: OrdererOrg

        # ID to load the MSP definition as
        ID: OrdererMSP

        # 这里差不多是硬编码了这个组织的 MSP 目录。
        # MSPDir is the filesystem path which contains the MSP configuration
        MSPDir: crypto-config/ordererOrganizations/example.com/msp

    - &Org1
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: Org1MSP

        # ID to load the MSP definition as
        # 对比上下两个组织，name 可以和 id 一样，也可以和 id 不一样。
        ID: Org1MSP

        MSPDir: crypto-config/peerOrganizations/org1.example.com/msp

        AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
            - Host: peer0.org1.example.com
              Port: 7051

    - &Org2
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: Org2MSP

        # ID to load the MSP definition as
        ID: Org2MSP

        MSPDir: crypto-config/peerOrganizations/org2.example.com/msp

        AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
            - Host: peer0.org2.example.com
              Port: 7051

################################################################################
#
#   SECTION: Orderer
#
#   - This section defines the values to encode into a config transaction or
#   genesis block for orderer related parameters
#
################################################################################
# 这里就是 anchor 了。
Orderer: &OrdererDefaults

    # Orderer Type: The orderer implementation to start
    # Available types are "solo" and "kafka"
    OrdererType: solo

    Addresses:
        - orderer.example.com:7050

    # Batch Timeout: The amount of time to wait before creating a batch
    BatchTimeout: 2s

    # Batch Size: Controls the number of messages batched into a block
    BatchSize:

        # Max Message Count: The maximum number of messages to permit in a batch
        MaxMessageCount: 10

        # Absolute Max Bytes: The absolute maximum number of bytes allowed for
        # the serialized messages in a batch.
        AbsoluteMaxBytes: 99 MB

        # Preferred Max Bytes: The preferred maximum number of bytes allowed for
        # the serialized messages in a batch. A message larger than the preferred
        # max bytes will result in a batch larger than preferred max bytes.
        PreferredMaxBytes: 512 KB

    Kafka:
        # Brokers: A list of Kafka brokers to which the orderer connects
        # NOTE: Use IP:port notation
        Brokers:
            - 127.0.0.1:9092

    # Organizations is the list of orgs which are defined as participants on
    # the orderer side of the network
    Organizations:

################################################################################
#
#   SECTION: Application
#
#   - This section defines the values to encode into a config transaction or
#   genesis block for application related parameters
#
################################################################################
Application: &ApplicationDefaults

    # Organizations is the list of orgs which are defined as participants on
    # the application side of the network
    Organizations:
```

## docker-compose 的配置文件分析

服务的定义依赖关系大概是 peer-base.yaml -> docker-compose-base.yaml -> docker-compose-cli.yaml。

### 常见环境变量前缀

Orderer 相关的环境变量开头是`ORDERER_GENERAL_`。

Peer 相关的环境变量开头是`CORE_PEER_`。

其他环境变量开头是`CORE_`。

### peer-base.yaml

启动 chaincode 容器都是在本**网桥**网络里启动的。

它的工作目录是`/opt/gopath/src/github.com/hyperledger/fabric/peer`。二进制的可执行文件应该都在 gopath 下。

它的工作路径里有二进制的 peer 文件，所以可以直接`peer node start`启动。

它的所谓的 vm enpoint 看起来就是容器服务治理的思路，用 port 来做 endpoint 的端点`CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock`。

```yaml
# 这个文件夹是纯净的，与 example 组织无关。
version: '2'

services:
  peer-base:
    image: hyperledger/fabric-peer:$IMAGE_TAG
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      # 用默认的网桥网络来启动链码容器。
      # the following setting starts chaincode containers on the same
      # bridge network as the peers
      # https://docs.docker.com/compose/networking/
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_byfn
      #- CORE_LOGGING_LEVEL=ERROR
      - CORE_LOGGING_LEVEL=DEBUG
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
```

### docker-compose-base.yaml

```yaml
version: '2'

services:
  # orderer 的配置
  orderer.example.com:
    container_name: orderer.example.com
    image: hyperledger/fabric-orderer:$IMAGE_TAG
    environment:
      - ORDERER_GENERAL_LOGLEVEL=debug
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      # 这个给 orderer 准备的创世区块，看下面的 volumes 的映射
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
      # enabled TLS
      - ORDERER_GENERAL_TLS_ENABLED=true
      # 服务器的 key
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      # 服务器的证书
      - ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      # ca 的证书
      - ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    # 启动命令，不像 peer，不再需要加参数了。
    command: orderer
    volumes:
    # 对创世区块的映射  
    - ../channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
    # 对 msp 文件夹的映射
    - ../crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp
    # 对 tls 文件夹的映射
    - ../crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/:/var/hyperledger/orderer/tls
    # 注意，这一步需要的命名卷，实际上就是要在 docker-compose-cli 里被顶层 volume 实例化
    - orderer.example.com:/var/hyperledger/production/orderer
    ports:
      - 7050:7050

  peer0.org1.example.com:
    # 经典的继承语法
    container_name: peer0.org1.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      # 外部的流言地址，和本机的 peer 地址一样
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
    volumes:
        - /var/run/:/host/var/run/
        # peer 容器必备：MSP 与 TLS 文件夹
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls:/etc/hyperledger/fabric/tls
        - peer0.org1.example.com:/var/hyperledger/production
    ports:
      - 7051:7051
      - 7053:7053

  peer1.org1.example.com:
    container_name: peer1.org1.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer1.org1.example.com
      - CORE_PEER_ADDRESS=peer1.org1.example.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org1.example.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls:/etc/hyperledger/fabric/tls
        - peer1.org1.example.com:/var/hyperledger/production

    ports:
      - 8051:7051
      - 8053:7053

  peer0.org2.example.com:
    container_name: peer0.org2.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer0.org2.example.com
      - CORE_PEER_ADDRESS=peer0.org2.example.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org2.example.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org2.example.com:7051
      - CORE_PEER_LOCALMSPID=Org2MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls:/etc/hyperledger/fabric/tls
        - peer0.org2.example.com:/var/hyperledger/production
    ports:
      - 9051:7051
      - 9053:7053
  # 所有节点的变化：
  # 1 修改 service name。
  # 2 修改 container_name
  # 3 修改本 peer 地址
  # 4 修改 gossip 相关，实际上还是本机地址
  peer1.org2.example.com:
    container_name: peer1.org2.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer1.org2.example.com
      - CORE_PEER_ADDRESS=peer1.org2.example.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org2.example.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org2.example.com:7051
      - CORE_PEER_LOCALMSPID=Org2MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls:/etc/hyperledger/fabric/tls
        - peer1.org2.example.com:/var/hyperledger/production
    ports:
      - 10051:7051
      - 10053:7053
```

### docker-compose-cli.yaml

在cli 容器内的的Gopath 就是普通的 /opt/gopath。

在容器内有四个已经写好的目录，要映射到本地目录上才能用，映射关系大致是：

./../chaincode/:/opt/gopath/src/github.com/hyperledger/fabric/examples/chaincode/go
./scripts:/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/：脚本的位置，这里应该可以放一些让容器外的控制命令操纵整个 fabric 的脚本。
./channel-artifacts:/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts：当然这就是 channel 的器物所在地了。 本身的相关文件的放置地。

```yaml
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# 当前 compose 语法已经升级到了 version 3了。
version: '2'

# 官方文档的释义，大义是顶级的 volume 元素是为了在不同的 service 之间共享 volume 而准备的。
# You can mount a host path as part of a definition for a single service, and there is no need to define it in the top level volumes key.
# But, if you want to reuse a volume across multiple services, then define a named volume in the top-level volumes key. Use named volumes with services, swarms, and stack files.
volumes:
  # 这个语法相当于声明了若干个命名卷。不同的容器之间把相同的卷挂载到自己本地的路径里，就相当于打通了两个容器的数据共享。
  # 注意，命名卷的开头并不是路径形式的，所以不要求当前的 host 有这个名字的绝对路径或者相对路径。
  orderer.ORDERER_DOMAIN:
  peer0.org1.example.com:
  peer1.org1.example.com:
  peer0.org2.example.com:
  peer1.org2.example.com:

# 一个顶级网络名称，供服务之间引用
networks:
  byfn:

services:
  orderer.ORDERER_DOMAIN:
    extends:
      file:   base/docker-compose-base.yaml
      service: orderer.ORDERER_DOMAIN
    # 在这里虽然可以覆盖 container name，但有必要么？
    container_name: orderer.ORDERER_DOMAIN
    networks:
      # 这是要加入的网络名称
      - byfn

  peer0.org1.example.com:
    container_name: peer0.org1.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer0.org1.example.com
    networks:
      - byfn

  peer1.org1.example.com:
    container_name: peer1.org1.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer1.org1.example.com
    networks:
      - byfn

  peer0.org2.example.com:
    container_name: peer0.org2.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer0.org2.example.com
    networks:
      - byfn

  peer1.org2.example.com:
    container_name: peer1.org2.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer1.org2.example.com
    networks:
      - byfn

  cli:
    container_name: cli
    # 这里不继承任何配置文件，而是直接使用镜像初始化容器
    image: hyperledger/fabric-tools:$IMAGE_TAG
    tty: true
    environment:
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_LOGGING_LEVEL=DEBUG
      - CORE_PEER_ID=cli
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    # 容器运行的时候，就会在内部的 console 里启动这段命令。类似我们经常 docker run 使用的 /bin/bash 一样。
    # 在这里我们传导了两个关键的环境变量进去，一个频道名，一个延迟。这也是目前唯二的还能在 cli 容器启动时改变的东西了。
    command: /bin/bash -c './scripts/script.sh ${CHANNEL_NAME} ${DELAY}; sleep $TIMEOUT'
    volumes:
        # host 上路径: 容器内路径
        # 映射本机的运行时配置文件到容器内。
        - /var/run/:/host/var/run/
        # ：这就是链码的主要位置了，看来这个目录也是镜像里就写死的，要写自定义的链码也只能从这里安装进去。
        - ./../chaincode/:/opt/gopath/src/github.com/hyperledger/fabric/examples/chaincode/go
        - ./crypto-config:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/
        - ./scripts:/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/
        - ./channel-artifacts:/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts
    depends_on:
      # 等这些 service 启动完了，再启动自己这个 service。
      - orderer.ORDERER_DOMAIN
      - peer0.org1.example.com
      - peer1.org1.example.com
      - peer0.org2.example.com
      - peer1.org2.example.com
    networks:
      - byfn
```
### docker-compose-e2e-template.yaml

```yaml
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# 这个文件会被 byfn.sh 的 replacePrivateKey() 函数生成实际的 docker-compose-e2e.yaml。
# 然后被 sed 命令另作他用。
version: '2'

volumes:
  orderer.example.com:
  peer0.org1.example.com:
  peer1.org1.example.com:
  peer0.org2.example.com:
  peer1.org2.example.com:

networks:
  byfn:
services:
  ca0:
    image: hyperledger/fabric-ca:$IMAGE_TAG
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-org1
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem
      - FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/CA1_PRIVATE_KEY
    ports:
      - "7054:7054"
    command: sh -c 'fabric-ca-server start --ca.certfile /etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem --ca.keyfile /etc/hyperledger/fabric-ca-server-config/CA1_PRIVATE_KEY -b admin:adminpw -d'
    volumes:
      - ./crypto-config/peerOrganizations/org1.example.com/ca/:/etc/hyperledger/fabric-ca-server-config
    container_name: ca_peerOrg1
    networks:
      - byfn

  ca1:
    image: hyperledger/fabric-ca:$IMAGE_TAG
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-org2
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org2.example.com-cert.pem
      - FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/CA2_PRIVATE_KEY
    ports:
      - "8054:7054"
    command: sh -c 'fabric-ca-server start --ca.certfile /etc/hyperledger/fabric-ca-server-config/ca.org2.example.com-cert.pem --ca.keyfile /etc/hyperledger/fabric-ca-server-config/CA2_PRIVATE_KEY -b admin:adminpw -d'
    volumes:
      - ./crypto-config/peerOrganizations/org2.example.com/ca/:/etc/hyperledger/fabric-ca-server-config
    container_name: ca_peerOrg2
    networks:
      - byfn

  orderer.example.com:
    extends:
      file:   base/docker-compose-base.yaml
      service: orderer.example.com
    container_name: orderer.example.com
    networks:
      - byfn

  peer0.org1.example.com:
    container_name: peer0.org1.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer0.org1.example.com
    networks:
      - byfn

  peer1.org1.example.com:
    container_name: peer1.org1.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer1.org1.example.com
    networks:
      - byfn

  peer0.org2.example.com:
    container_name: peer0.org2.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer0.org2.example.com
    networks:
      - byfn

  peer1.org2.example.com:
    container_name: peer1.org2.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer1.org2.example.com
    networks:
      - byfn
```

### byfn.sh

```bash
#!/bin/bash

#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script will orchestrate a sample end-to-end execution of the Hyperledger
# Fabric network.
#
# The end-to-end verification provisions a sample Fabric network consisting of
# two organizations, each maintaining two peers, and a “solo” ordering service.
#
# This verification makes use of two fundamental tools, which are necessary to
# create a functioning transactional network with digital signature validation
# and access control:
#
# * cryptogen - generates the x509 certificates used to identify and
#   authenticate the various components in the network.
# * configtxgen - generates the requisite configuration artifacts for orderer
#   bootstrap and channel creation.
#
# Each tool consumes a configuration yaml file, within which we specify the topology
# of our network (cryptogen) and the location of our certificates for various
# configuration operations (configtxgen).  Once the tools have been successfully run,
# we are able to launch our network.  More detail on the tools and the structure of
# the network will be provided later in this document.  For now, let's get going...

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/../bin:${PWD}:$PATH
# 这个环境变量很重要，这里的 export 保证这个变量是在 environment 里。可以被子进程（另一个 shell 脚本继承）。
# 并不是所有的父进程里的 variable 都会被子进程看到的。
export FABRIC_CFG_PATH=${PWD}

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  byfn.sh -m up|down|restart|generate [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-i <imagetag>]"
  echo "  byfn.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'up', 'down', 'restart' or 'generate'"
  echo "      - 'up' - bring up the network with docker-compose up"
  echo "      - 'down' - clear the network with docker-compose down"
  echo "      - 'restart' - restart the network"
  echo "      - 'generate' - generate required certificates and genesis block"
  echo "    -c <channel name> - channel name to use (defaults to \"mychannel\")"
  echo "    -t <timeout> - CLI timeout duration in microseconds (defaults to 10000)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)"
  echo "    -s <dbtype> - the database backend to use: goleveldb (default) or couchdb"
  echo "    -i <imagetag> - pass the image tag to launch the network using the tag: 1.0.1, 1.0.2, 1.0.3, 1.0.4 (defaults to latest)"
  echo
  echo "Typically, one would first generate the required certificates and "
  echo "genesis block, then bring up the network. e.g.:"
  echo
  echo "  byfn.sh -m generate -c mychannel"
  echo "  byfn.sh -m up -c mychannel -s couchdb"
  echo "  byfn.sh -m up -c mychannel -s couchdb -i 1.0.6"
  echo "  byfn.sh -m down -c mychannel"
  echo
  echo "Taking all defaults:"
  echo "  byfn.sh -m generate"
  echo "  byfn.sh -m up"
  echo "  byfn.sh -m down"
}

# Ask user for confirmation to proceed
function askProceed () {
  read -p "Continue (y/n)? " ans
  case "$ans" in
    y|Y )
      # 只有这个地方会正常走下去
      echo "proceeding ..."
    # 这个双分号是 case 的休止符
    ;;
    n|N )
      echo "exiting..."
      exit 1
    ;;
    * )
      # 这里会递归
      echo "invalid response"
      askProceed
    ;;
  esac
}

# Obtain CONTAINER_IDS and remove them
# TODO Might want to make this optional - could clear other containers
function clearContainers () {
  # -a 表示输出全部容器，-q 表示只输出容器 id，这样就可以迭代使用了
  # 结果大概是这样
  # 8a25b455f05e
  # d2d84545a902
  # c67d337e5bd9
  # e5cbd8457caf
  # 9ee6a1cb33c1
  # a0df580d4633
  # cb6b441b083f
  # 0c87d55710c8
  # c24f3eb2e0e0
  CONTAINER_IDS=$(docker ps -aq)
  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    echo "---- No containers available for deletion ----"
  else
    # 直接拿这个列表来 rm，而不用再 xargs 了。
    docker rm -f $CONTAINER_IDS
  fi
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# TODO list generated image naming patterns
function removeUnwantedImages() {
  # 用 awk 来截取多段输出的好例子。
  # 注意在这里我们可以看到不要乱改 peer 的名字，不然不能在这里搞到所有的 image_id。
  # $()的形式可以把命令求和为一个匿名变量。
  DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
}

# Generate the needed certificates, the genesis block and start the network.
function networkUp () {
  # generate artifacts if they don't exist
  # 确认一个目录是否存在的命令
  if [ ! -d "crypto-config" ]; then
    # 第一步，生成证书。其实不只是生成证书，还生成证书相关的东西。
    generateCerts
    replacePrivateKey
    generateChannelArtifacts
  fi
  if [ "${IF_COUCHDB}" == "couchdb" ]; then
      IMAGE_TAG=$IMAGETAG CHANNEL_NAME=$CHANNEL_NAME TIMEOUT=$CLI_TIMEOUT DELAY=$CLI_DELAY docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d 2>&1
  else
      # 这一行让 Docker-Compose 来按照配置文件装配容器配置，生成由容器组成的项目网络
      # cli 容器起来以后，会自己去创建频道、一个一个地把容器加入网络中。一个一个地初始化链码，一个一个地测试链码。
      IMAGE_TAG=$IMAGETAG CHANNEL_NAME=$CHANNEL_NAME TIMEOUT=$CLI_TIMEOUT DELAY=$CLI_DELAY docker-compose -f $COMPOSE_FILE up -d 2>&1
  fi
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    # 这个命令就是去读一个容器启动的 command 在 console 里的输出。
    docker logs -f cli
    exit 1
  fi
  docker logs -f cli
}

# Tear down running network
function networkDown () {
  docker-compose -f $COMPOSE_FILE down --volumes
  docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH down --volumes
  # Don't remove the generated artifacts -- note, the ledgers are always removed
  if [ "$MODE" != "restart" ]; then
    # Bring the containers down deleting their volumes
    #Cleanup the chaincode containers
    clearContainers
    #Cleanup images
    removeUnwantedImages
    # remove orderer block and other channel configuration transactions and certs
    rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config
    # remove the docker-compose yaml file that was customized to the example
    rm -f docker-compose-e2e.yaml
  fi
}

# 但这个文件有什么用呢？docker-compose-e2e-template.yaml 
# Using docker-compose-e2e-template.yaml, replace constants with private key file names
# generated by the cryptogen tool and output a docker-compose.yaml specific to this
# configuration
function replacePrivateKey () {
  # sed on MacOSX does not support -i flag with a null extension. We will use
  # 't' for our back-up's extension and depete it at the end of the function
  ARCH=`uname -s | grep Darwin`
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi

  # Copy the template to the file that will be modified to add the private key
  cp docker-compose-e2e-template.yaml docker-compose-e2e.yaml

  # The next steps will replace the template's contents with the
  # actual values of the private key file names for the two CAs.
  # 把当前的父文件夹记住
  CURRENT_DIR=$PWD
  cd crypto-config/peerOrganizations/org1.example.com/ca/
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR"
  sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
  cd crypto-config/peerOrganizations/org2.example.com/ca/
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR"
  sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm docker-compose-e2e.yamlt
  fi
}

# X.509只是 PKI 密码学架构的一个实现。
# ca-cert 是根证书。
# 为什么 count 必须放在这个文件里面。
# 这个函数不止生成证书，还有 keystore。
# 私钥签署，公钥验证！而不是公钥签署，私钥验证！
# We will use the cryptogen tool to generate the cryptographic material (x509 certs)
# for our various network entities.  The certificates are based on a standard PKI
# implementation where validation is achieved by reaching a common trust anchor.
#
# Cryptogen consumes a file - ``crypto-config.yaml`` - that contains the network
# topology and allows us to generate a library of certificates for both the
# Organizations and the components that belong to those Organizations.  Each
# Organization is provisioned a unique root certificate (``ca-cert``), that binds
# specific components (peers and orderers) to that Org.  Transactions and communications
# within Fabric are signed by an entity's private key (``keystore``), and then verified
# by means of a public key (``signcerts``).  You will notice a "count" variable within
# this file.  We use this to specify the number of peers per Organization; in our
# case it's two peers per Org.  The rest of this template is extremely
# self-explanatory.
#
# After we run the tool, the certs will be parked in a folder titled ``crypto-config``.

# Generates Org certs using cryptogen tool
function generateCerts (){
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "##########################################################"
  echo "##### Generate certificates using cryptogen tool #########"
  echo "##########################################################"
  if [ -d "crypto-config" ]; then
    rm -Rf crypto-config
  fi
  cryptogen generate --config=./crypto-config.yaml
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate certificates..."
    exit 1
  fi
  echo
}

# 每一个新的 org 都要有一个 anchor 节点。这也就意味着不仅配置文件里要有相关的配置，也意味着初始化步骤里
# 要有相关的配置命令。
# 把三件事做起来：
# 1 生成创世区块。 2 生成频道配置 3 配置锚节点。
#
# The `configtxgen tool is used to create four artifacts: orderer **bootstrap
# block**, fabric **channel configuration transaction**, and two **anchor
# peer transactions** - one for each Peer Org.
#
# The orderer block is the genesis block for the ordering service, and the
# channel transaction file is broadcast to the orderer at channel creation
# time.  The anchor peer transactions, as the name might suggest, specify each
# Org's anchor peer on this channel.
#
# Configtxgen consumes a file - ``configtx.yaml`` - that contains the definitions
# for the sample network. There are three members - one Orderer Org (``OrdererOrg``)
# and two Peer Orgs (``Org1`` & ``Org2``) each managing and maintaining two peer nodes.
# This file also specifies a consortium - ``SampleConsortium`` - consisting of our
# two Peer Orgs.  Pay specific attention to the "Profiles" section at the top of
# this file.  You will notice that we have two unique headers. One for the orderer genesis
# block - ``TwoOrgsOrdererGenesis`` - and one for our channel - ``TwoOrgsChannel``.
# These headers are important, as we will pass them in as arguments when we create
# our artifacts.  This file also contains two additional specifications that are worth
# noting.  Firstly, we specify the anchor peers for each Peer Org
# (``peer0.org1.example.com`` & ``peer0.org2.example.com``).  Secondly, we point to
# the location of the MSP directory for each member, in turn allowing us to store the
# root certificates for each Org in the orderer genesis block.  This is a critical
# concept. Now any network entity communicating with the ordering service can have
# its digital signature verified.
#
# This function will generate the crypto material and our four configuration
# artifacts, and subsequently output these files into the ``channel-artifacts``
# folder.
#
# If you receive the following warning, it can be safely ignored:
#
# [bccsp] GetDefault -> WARN 001 Before using BCCSP, please call InitFactories(). Falling back to bootBCCSP.
#
# You can ignore the logs regarding intermediate certs, we are not using them in
# this crypto implementation.

# Generate orderer genesis block, channel configuration transaction and
# anchor peer update transactions
function generateChannelArtifacts() {
  # 检测一个命令是不是存在
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "##########################################################"
  echo "#########  Generating Orderer Genesis block ##############"
  echo "##########################################################"
  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  # 1 生成创世区块
  configtxgen -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/genesis.block
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo
  echo "#################################################################"
  echo "### Generating channel configuration transaction 'channel.tx' ###"
  echo "#################################################################"
  # 2 生成频道配置，实际上就是 channel 事务。
  configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for Org1MSP   ##########"
  echo "#################################################################"
  # configtxgen -help 可以看到它的各种 options。其中 outputAnchorPeersUpdate 只能在创建缺省频道（实际上自定义频道也可以），和最初建 anchor 时才可以使用。
  # 这个 channel 名和 asOrg 参数共同决定 Org1MSPanchors.tx 的内容。
  configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate anchor peer update for Org1MSP..."
    exit 1
  fi

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for Org2MSP   ##########"
  echo "#################################################################"
  configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate \
  ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate anchor peer update for Org2MSP..."
    exit 1
  fi
  echo
}

# 定义完函数以后，这里才是程序的起点
# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform
OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
#default for delay
CLI_DELAY=3
# channel name defaults to "mychannel"
CHANNEL_NAME="mychannel"
# use this as the default docker-compose yaml definition
COMPOSE_FILE=docker-compose-cli.yaml
#
COMPOSE_FILE_COUCH=docker-compose-couch.yaml
# default image tag
IMAGETAG="latest"
# Parse commandline args
while getopts "h?m:c:t:d:f:s:i:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    m)  MODE=$OPTARG
    ;;
    c)  CHANNEL_NAME=$OPTARG
    ;;
    t)  CLI_TIMEOUT=$OPTARG
    ;;
    d)  CLI_DELAY=$OPTARG
    ;;
    f)  COMPOSE_FILE=$OPTARG
    ;;
    s)  IF_COUCHDB=$OPTARG
    ;;
    i)  IMAGETAG=`uname -m`"-"$OPTARG
    ;;
  esac
done

# Determine whether starting, stopping, restarting or generating for announce
if [ "$MODE" == "up" ]; then
  EXPMODE="Starting"
  elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping"
  elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting"
  elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and genesis block for"
else
  printHelp
  exit 1
fi

# Announce what was requested

  if [ "${IF_COUCHDB}" == "couchdb" ]; then
        echo
        echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' using database '${IF_COUCHDB}'"
  else
        echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}'"
  fi
# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
  networkUp
  elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
  elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateCerts
  replacePrivateKey
  generateChannelArtifacts
  elif [ "${MODE}" == "restart" ]; then ## Restart the network
  networkDown
  networkUp
else
  printHelp
  exit 1
fi
```

### script/script.sh

```bash
#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build your first network (BYFN) end-to-end test"
echo
CHANNEL_NAME="$1"
DELAY="$2"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
# 是不是使用 TLS，其实只与 orderer 和 channel 有关。
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ORDERER_DOMAIN/orderers/orderer.ORDERER_DOMAIN/msp/tlscacerts/tlsca.ORDERER_DOMAIN-cert.pem

echo "Channel name : "$CHANNEL_NAME

# verify the result of the end-to-end test
verifyResult () {
  if [ $1 -ne 0 ] ; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
    echo
      exit 1
  fi
}

setGlobals () {

  if [ $1 -eq 0 -o $1 -eq 1 ] ; then
    CORE_PEER_LOCALMSPID="Org1MSP"
    CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    # 传进来不同的命令，更改的核心环境变量指标是容器的 endpoint 地址。也就是CORE_PEER_ADDRESS。相同组织的 enpoint 使用的是相同的 MSP 密码学目录。
    if [ $1 -eq 0 ]; then
      CORE_PEER_ADDRESS=peer0.org1.example.com:7051
    else
      CORE_PEER_ADDRESS=peer1.org1.example.com:7051
      # 此处有重复，疑为错误。但 github 上原版的代码就是这样写的。
      CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    fi
  else
    CORE_PEER_LOCALMSPID="Org2MSP"
    CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    if [ $1 -eq 2 ]; then
      CORE_PEER_ADDRESS=peer0.org2.example.com:7051
    else
      CORE_PEER_ADDRESS=peer1.org2.example.com:7051
    fi
  fi

  env |grep CORE
}

# 创建频道是第一步
createChannel() {
  # 把 cli 内的全局变量设置为0系列
  setGlobals 0

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
      # 1 -o 是 orderer string，实际上就是从cli 容器出发，可以读到的容器地址，这里还要考虑容器网络连通性问题。-c 是频道名。channel.tx是不可读文件。
      # 换言之，如果我们有足够多的创世区块，和 channel.tx。我们可以在一个 cli 容器里面生成多个频道。
      # 2 实际上我们从这一步开始，就知道了 orderer 才是最先 join 进这个 channel 里的一个节点。
      # 3 几乎所有的频道、peer、orderer 节点相关的操作，都要依靠这个 peer channel 命令开头的系列命令。
      # 4 channel id 就是 channel name。
    peer channel create -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&log.txt
  else
    # 注意，如果需要打开 tls，那么这个--cafile选项特别特别重要。
    peer channel create -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
  fi
  res=$?
  cat log.txt
  verifyResult $res "Channel creation failed"
  echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
  echo
}

updateAnchorPeers() {
  PEER=$1
  setGlobals $PEER

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
      # 生成的 anchor artifact 到这里才有用。这样才算真的把锚节点注册上去了。
    peer channel update -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
  else
    peer channel update -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
  fi
  res=$?
  cat log.txt
  verifyResult $res "Anchor peer update failed"
  echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
  sleep $DELAY
  echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
  # peer channel join 实际上是消耗四个环境变量作为把 peer 加入 channel 的依据，所以外部传进来的环境变量到此几乎可说是无用的。
  # CORE_PEER_MSPCONFIGPATH
  # CORE_PEER_ADDRESS
  # CORE_PEER_LOCALMSPID
  # CORE_PEER_TLS_ROOTCERT_FILE
  peer channel join -b $CHANNEL_NAME.block  >&log.txt
  res=$?
  cat log.txt
  if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
    COUNTER=` expr $COUNTER + 1`
    # 这的 peer 是顺序 peer，和实际的容器名是不一样的。
    echo "PEER$1 failed to join the channel, Retry after 2 seconds"
    # bash sleep 的妙用
    sleep $DELAY
    # 递归重试
    joinWithRetry $1
  else
    COUNTER=1
  fi
  verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
  for ch in 0 1 2 3; do
    setGlobals $ch
    joinWithRetry $ch
    echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
    sleep $DELAY
    echo
  done
}

installChaincode () {
  PEER=$1
  setGlobals $PEER
  # 这里这个 p 就是在cli 容器内可以看到的 chaincode 的 go 文件路径了。n 则是链码的合约名字。
  # 这个链码为什么不需要经过编译，真是奇也怪哉。
  peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02 >&log.txt
  res=$?
  cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
  echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
  echo
}

instantiateChaincode () {
  PEER=$1
  setGlobals $PEER
  # 用硬编码的方式好过用接口的方式来读写 orderer endpoint 的位置。
  # while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
  # lets supply it directly as we know it using the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    # 在链码初始化的时候，制定背书策略。
    # 供反射调用
    peer chaincode instantiate -o orderer.ORDERER_DOMAIN:7050 -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR ('Org1MSP.member','Org2MSP.member')" >&log.txt
  else
    peer chaincode instantiate -o orderer.ORDERER_DOMAIN:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR ('Org1MSP.member','Org2MSP.member')" >&log.txt
  fi
  res=$?
  cat log.txt
  verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  echo
}

chaincodeQuery () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep $DELAY
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$2" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
  echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
  echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
  echo
  exit 1
  fi
}

chaincodeInvoke () {
  PEER=$1
  setGlobals $PEER
  # while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
  # lets supply it directly as we know it using the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    # -c 是调用的消息的构造函数的参数。后台基本上是用反射什么的来执行调用的。
    peer chaincode invoke -o orderer.ORDERER_DOMAIN:7050 -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
  else
    peer chaincode invoke -o orderer.ORDERER_DOMAIN:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
  fi
  res=$?
  cat log.txt
  verifyResult $res "Invoke execution on PEER$PEER failed "
  echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  echo
}

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
# 这两个函数调用，要仔细更改当前的核心环境变量为两个组织预先生成好的 anchor 节点的 endpoint。
updateAnchorPeers 0
echo "Updating anchor peers for org2..."
updateAnchorPeers 2

# 只在 peer0 和 peer2上安装合约
## Install chaincode on Peer0/Org1 and Peer2/Org2
echo "Installing chaincode on org1/peer0..."
installChaincode 0
echo "Install chaincode on org2/peer2..."
installChaincode 2

# 只在 peer2上初始化合约
#Instantiate chaincode on Peer2/Org2
echo "Instantiating chaincode on org2/peer2..."
instantiateChaincode 2

# 只在 peer0 上查询合约
#Query on chaincode on Peer0/Org1
echo "Querying chaincode on org1/peer0..."
chaincodeQuery 0 100

# 只在 peer0 上调用合约
#Invoke on chaincode on Peer0/Org1
echo "Sending invoke transaction on org1/peer0..."
chaincodeInvoke 0

# 在 peer3 上追加安装合约 
## Install chaincode on Peer3/Org2
echo "Installing chaincode on org2/peer3..."
installChaincode 3

# 在 peer3 上追加查询合约。可见追加进来的合约调用结果可以被明确查询到。
#Query on chaincode on Peer3/Org2, check if the result is 90
echo "Querying chaincode on org2/peer3..."
chaincodeQuery 3 90

echo
echo "========= All GOOD, BYFN execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
```