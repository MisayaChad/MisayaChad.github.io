---
title: 超级账本 Hyperledger Fabric2.0 多机集群部署
date: 2020-5-20 15:33:30
categories: 区块链
---

# 我们需要将容器分发到4个主机，本教程使用的是局域网下的四台主机。系统为Ubuntu和centos均可以。可以自己随便设置，保证能互相联通
![](/images/fabric2.0多机集群部署结构.jpg)

## 在Fabric网络启动运行后，我们将使用Fabcar链码进行测试。总体流程如下：

准备4台可以互相通信的主机，均为linu内核。
构建一个叠加网络，将4个主机都加入该网络
在主机1上准备所有资料，包括密码学资料、通道配置交易、每个节点的docker-compose文件等。然后拷贝到其他主机。
使用docker-compose启动所有组件
创建通道mychannel并将所有peer加入该通道
安装并实例化Fabcar链码
调用查询链码方法

### 使用Docker Swarm构建叠加网络
- 在host1初始化swarm集群
```shell
docker swarm init
```
- 在host1上创建swarm网络
```shell
docker network create --attachable --driver overlay first-network
```
- 在其余host上（以管理节点的身份）加入swarm网络
```shell
docker swarm join --token xxxxxxxxxxx
```

- 验证每台host上是否有名称为first-network网络
```shell
docker network ls
```

### 在host1上准备材料
- 首先进入fabric-samples目录，如果还没有fabric-samples，自行在github上面去当去该项目，然后创建一个raft-4node-swarm目录。

```shell
cd fabric-samples
mkdir raft-4node-swarm
cd raft-4node-swarm
```

- 直接从first-network拷贝crypto-config.yaml和configtx.yaml文件
```shell
cp ../first-network/crypto-config.yaml .
cp ../first-network/configtx.yaml .
```

- 直接从config拷贝core.yaml和orderer.yaml文件,并修改core.yaml中mspConfigPath内容
```shell
cp ../config/core.yaml .
cp ../config/orderer.yaml .
```

#### core.yaml更改前
```yaml
 # Path on the file system where peer will find MSP local configurations
    mspConfigPath: msp
```
#### core.yaml更改后
```yaml
 # Path on the file system where peer will find MSP local configurations
    mspConfigPath: crypto-config/ordererOrganizations/example.com/msp
```

- 其中 crypto-config.yaml 用于生成MSP相关证书，育有组织架构和节点数和first-network一样，所以不作修改。
其中configtx.yaml用于生成创世区块，交易通道配置等，由于节点的通信地址变化，所以共识机制配置中排序节点的通信地址要更改，更改内容如下

#### configtx.yaml更改前：
```yaml

   - &Org2
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: Org2MSP

        # ID to load the MSP definition as
        ID: Org2MSP

        MSPDir: crypto-config/peerOrganizations/org2.example.com/msp

        # Policies defines the set of policies at this level of the config tree
        # For organization policies, their canonical path is usually
        #   /Channel/<Application|Orderer>/<OrgName>/<PolicyName>
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.peer', 'Org2MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org2MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org2MSP.peer')"

        AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
            - Host: peer0.org2.example.com
              Port: 9051

    SampleMultiNodeEtcdRaft:
        <<: *ChannelDefaults
        Capabilities:
            <<: *ChannelCapabilities
        Orderer:
            <<: *OrdererDefaults
            OrdererType: etcdraft
            EtcdRaft:
                Consenters:
                - Host: orderer.example.com
                  Port: 7050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
                - Host: orderer2.example.com
                  Port: 8050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt
                - Host: orderer3.example.com
                  Port: 9050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/tls/server.crt
                - Host: orderer4.example.com
                  Port: 10050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt
                - Host: orderer5.example.com
                  Port: 11050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/tls/server.crt
            Addresses:
                - orderer.example.com:7050
                - orderer2.example.com:8050
                - orderer3.example.com:9050
                - orderer4.example.com:10050
                - orderer5.example.com:11050
```

#### configtx.yaml更改后：
```yaml

     - &Org2
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: Org2MSP

        # ID to load the MSP definition as
        ID: Org2MSP

        MSPDir: crypto-config/peerOrganizations/org2.example.com/msp

        # Policies defines the set of policies at this level of the config tree
        # For organization policies, their canonical path is usually
        #   /Channel/<Application|Orderer>/<OrgName>/<PolicyName>
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.peer', 'Org2MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org2MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org2MSP.peer')"

        AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
            - Host: peer0.org2.example.com
              Port: 7051

    SampleMultiNodeEtcdRaft:
        <<: *ChannelDefaults
        Capabilities:
            <<: *ChannelCapabilities
        Orderer:
            <<: *OrdererDefaults
            OrdererType: etcdraft
            EtcdRaft:
                Consenters:
                - Host: orderer.example.com
                  Port: 7050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
                - Host: orderer2.example.com
                  Port: 7050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt
                - Host: orderer3.example.com
                  Port: 7050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/tls/server.crt
                - Host: orderer4.example.com
                  Port: 7050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt
                - Host: orderer5.example.com
                  Port: 8050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/tls/server.crt
            Addresses:
                - orderer.example.com:7050
                - orderer2.example.com:7050
                - orderer3.example.com:7050
                - orderer4.example.com:7050
                - orderer5.example.com:8050
```

#### 然后根据配置文件生成必要的密码学资料：
```shell
../bin/cryptogen generate --config=./crypto-config.yaml
export FABRIC_CFG_PATH=$PWD
mkdir channel-artifacts
../bin/configtxgen -profile SampleMultiNodeEtcdRaft -outputBlock ./channel-artifacts/genesis.block -channelID byfn-sys-channel
../bin/configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID mychannel
../bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP
../bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP
```

#### 现在我们为所有主机准备docker-compose文件，主要基于BYFN中的文件，需要创建6个docker-compose文件以及一个env文件
- base/peer-base.yaml
- base/docker-compose-peer.yaml
- host1.yaml
- host2.yaml
- host3.yaml
- host4.yaml
- .env

##### base/peer-base.yaml 内容：
``` yaml

# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '2'

services:
  peer-base:
    image: hyperledger/fabric-peer:$IMAGE_TAG
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      # the following setting starts chaincode containers on the same
      # bridge network as the peers
      # https://docs.docker.com/compose/networking/
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=first-network
      - FABRIC_LOGGING_SPEC=INFO
      #- FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start

  orderer-base:
    image: hyperledger/fabric-orderer:$IMAGE_TAG
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
      # enabled TLS
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
      - ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1
      - ORDERER_KAFKA_VERBOSE=true
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: orderer

```

##### base/docker-compose-base.yaml 内容:
``` yaml

# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '2'

services:

  orderer.example.com:
    container_name: orderer.example.com
    extends:
      file: peer-base.yaml
      service: orderer-base
    volumes:
        - ../channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ../crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp
        - ../crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/:/var/hyperledger/orderer/tls
        - orderer.example.com:/var/hyperledger/production/orderer
    ports:
      - 7050:7050

  peer0.org1.example.com:
    container_name: peer0.org1.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org1.example.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls:/etc/hyperledger/fabric/tls
        - peer0.org1.example.com:/var/hyperledger/production
    ports:
      - 7051:7051

  peer1.org1.example.com:
    container_name: peer1.org1.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer1.org1.example.com
      - CORE_PEER_ADDRESS=peer1.org1.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer1.org1.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org1.example.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls:/etc/hyperledger/fabric/tls
        - peer1.org1.example.com:/var/hyperledger/production
    ports:
      - 7051:7051

  peer0.org2.example.com:
    container_name: peer0.org2.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer0.org2.example.com
      - CORE_PEER_ADDRESS=peer0.org2.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org2.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org2.example.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org2.example.com:7051
      - CORE_PEER_LOCALMSPID=Org2MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls:/etc/hyperledger/fabric/tls
        - peer0.org2.example.com:/var/hyperledger/production
    ports:
      - 7051:7051

  peer1.org2.example.com:
    container_name: peer1.org2.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer1.org2.example.com
      - CORE_PEER_ADDRESS=peer1.org2.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer1.org2.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org2.example.com:7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org2.example.com:7051
      - CORE_PEER_LOCALMSPID=Org2MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls:/etc/hyperledger/fabric/tls
        - peer1.org2.example.com:/var/hyperledger/production
    ports:
      - 7051:7051

```

##### host1.yaml 内容:
``` yaml

# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '2'

volumes:
  orderer.example.com:
  orderer5.example.com:
  peer0.org1.example.com:

networks:
  byfn:
    external:
      name: first-network

services:

  orderer.example.com:
    extends:
      file:   base/docker-compose-base.yaml
      service: orderer.example.com
    container_name: orderer.example.com
    networks:
      - byfn

  orderer5.example.com:
    extends:
      file: base/peer-base.yaml
      service: orderer-base
    environment:
      - ORDERER_GENERAL_LISTENPORT=7050
    container_name: orderer5.example.com
    networks:
    - byfn
    volumes:
        - ./channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/msp:/var/hyperledger/orderer/msp
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/tls/:/var/hyperledger/orderer/tls
        - orderer5.example.com:/var/hyperledger/production/orderer
    ports:
    - 8050:7050

  peer0.org1.example.com:
    container_name: peer0.org1.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer0.org1.example.com
    networks:
      - byfn

  cli:
    container_name: cli
    image: hyperledger/fabric-tools:$IMAGE_TAG
    tty: true
    stdin_open: true
    environment:
      - SYS_CHANNEL=$SYS_CHANNEL
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      #- FABRIC_LOGGING_SPEC=DEBUG
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_ID=cli
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash
    volumes:
        - /var/run/:/host/var/run/
        - ./../chaincode/:/opt/gopath/src/github.com/chaincode
        - ./crypto-config:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/
        - ./scripts:/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/
        - ./channel-artifacts:/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts
    depends_on:
      - orderer.example.com
      - peer0.org1.example.com
    networks:
      - byfn

```

##### host2.yaml 内容:
``` yaml

# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '2'

volumes:
  orderer2.example.com:
  peer1.org1.example.com:

networks:
  byfn:
    external:
      name: first-network

services:

  orderer2.example.com:
    extends:
      file: base/peer-base.yaml
      service: orderer-base
    container_name: orderer2.example.com
    networks:
    - byfn
    volumes:
        - ./channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/msp:/var/hyperledger/orderer/msp
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/:/var/hyperledger/orderer/tls
        - orderer2.example.com:/var/hyperledger/production/orderer
    ports:
    - 7050:7050

  peer1.org1.example.com:
    container_name: peer1.org1.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer1.org1.example.com
    networks:
      - byfn

```

##### host3.yaml 内容:
``` yaml

# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '2'

volumes:
  orderer3.example.com:  
  peer0.org2.example.com:

networks:
  byfn:
    external:
      name: first-network

services:

  orderer3.example.com:
    extends:
      file: base/peer-base.yaml
      service: orderer-base
    container_name: orderer3.example.com
    networks:
    - byfn
    volumes:
        - ./channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/msp:/var/hyperledger/orderer/msp
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/tls/:/var/hyperledger/orderer/tls
        - orderer3.example.com:/var/hyperledger/production/orderer
    ports:
    - 7050:7050

  peer0.org2.example.com:
    container_name: peer0.org2.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer0.org2.example.com
    networks:
      - byfn

```

##### host4.yaml 内容:
``` yaml

# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '2'

volumes:
  orderer4.example.com:
  peer1.org2.example.com:

networks:
  byfn:
    external:
      name: first-network

services:

  orderer4.example.com:
    extends:
      file: base/peer-base.yaml
      service: orderer-base
    container_name: orderer4.example.com
    networks:
    - byfn
    volumes:
        - ./channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/msp:/var/hyperledger/orderer/msp
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/:/var/hyperledger/orderer/tls
        - orderer4.example.com:/var/hyperledger/production/orderer
    ports:
    - 7050:7050

  peer1.org2.example.com:
    container_name: peer1.org2.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer1.org2.example.com
    networks:
      - byfn

```

##### .env （项目环境配置文件）内容
```

COMPOSE_PROJECT_NAME=net
IMAGE_TAG=latest
SYS_CHANNEL=byfn-sys-channel
```

#### 以上文件具体是针对BYFN中的文件所作的修改总结
- base/peer-base.yaml中，CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE修改为
我们之前创建的叠加网络first-network
- base/docker-compose-base.yaml中，由于所有的peers都在不同的主机上，我们
将端口映射改回7051:7051。在每个peer的环境变量中也进行了相应的修改。
- 在所有的hostn.yaml文件中，我们添加叠加网络first-network

#### 拷贝材料到其余机器
``` shell

cd ..
tar cf raft-4node-swarm.tar raft-4node-swarm
scp raft-4node-swarm.tar root@192.168.1.25:/root/go/src/github.com/hyperledger/fabric-samples
scp raft-4node-swarm.tar root@192.168.1.27:/root/go/src/github.com/hyperledger/fabric-samples
scp raft-4node-swarm.tar root@192.168.1.28:/root/go/src/github.com/hyperledger/fabric-samples
```

``` shell

#在host1、host2、host3上分别执行
cd /root/go/src/github.com/hyperledger/fabric-samples
rm -rf raft-4node-swarm
tar xf raft-4node-swarm.tar
cd raft-4node-swarm
```

#### 分别启动各主机上的容器
``` shell

# on Host 1, 2, 3 and 4, bring up corresponding yaml file
docker-compose -f hostn.yaml up -d
```

#### 为mychannel通道创建创世区块
``` shell

docker exec cli peer channel create -o orderer.example.com:7050 -c mychannel \
       -f ./channel-artifacts/channel.tx --tls true \
       --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

#### 将peer0.org1加入mychannel
``` shell

docker exec cli peer channel join -b mychannel.block
```

#### 将peer1.org1加入mychannel
``` shell

docker exec -e CORE_PEER_ADDRESS=peer1.org1.example.com:7051 \
       -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt \
       cli peer channel join -b mychannel.block
```

#### 将peer0.org2加入mychannel
``` shell

docker exec -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp \
       -e CORE_PEER_ADDRESS=peer0.org2.example.com:7051 -e CORE_PEER_LOCALMSPID="Org2MSP" \
       -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
       cli peer channel join -b mychannel.block
```

#### 将peer1.org2加入mychannel
``` shell

docker exec -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp \
       -e CORE_PEER_ADDRESS=peer1.org2.example.com:7051 -e CORE_PEER_LOCALMSPID="Org2MSP" \
       -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt \
       cli peer channel join -b mychannel.block
```

#### 安装并实例化Fabcar链码
进入到docker的cli终端
```shell

docker exec -it cli bash
```
查看当前cli容器环境变量
``` shell

env
```
正常会显示 CORE_PEER_LOCALMSPID=Org1MSP，表示以org1MSP身份操作

#### 打包合约
在cli容器内部执行
```shell
peer lifecycle chaincode package mycc1.tar.gz --path /opt/gopath/src/github.com/chaincode/abstore/go/ --lang golang --label mycc_1

# mycc1.tar.gz ：打包合约包文件名 
# --path 智能合约路径,可以在host1.yaml中查看cli容器的数据卷配置查询
# --lang 智能合约语言 支持golang、node、java
# --label  智能合约标签，描述作用
```

执行完成后，查看当前目录，会出现mycc1.tar.gz

#### 部署合约到节点
继续在cli内部执行以下命令,执行安装合约
```shell

peer lifecycle chaincode install mycc1.tar.gz
```

验证合约安装是否安装到节点
```shell

peer lifecycle chaincode queryinstalled
```
注意: 显示所有安装的合约包，记录label为mycc1的 Package ID

#### 当前组织同意合约定义
2.0智能合约由合约定义控制。当通道成员批准合约定义时，该批准作为组织对其接受的合约参数的投票。这些经过批准的组织定义允许通道成员在链码在通道上使用之前对链码达成一致。链码定义包括以下参数，这些参数需要在组织之间保持一致:

名称: 智能合约名称
版本: 与给定的合约包相关联的版本号或值。如果您升级了合约二进制文件，那么您也需要更改合约版本。
序列: 定义链码的次数。此值为整数，用于跟踪合约升级。例如，当您第一次安装并批准一个chaincode定义时，序列号将是1。下次升级合约时，序列号将增加到2。
背书策略: 哪些组织需要执行和验证事务输出。背书策略可以表示为传递给CLI或SDK的字符串，也可以在通道配置中引用策略。默认情况下，背书策略被设置为通道/应用程序/背书，这默认要求通道中的大多数组织对交易进行背书。
集合配置: 指向与您的chaincode关联的私有数据集合定义文件的路径。有关私有数据收集的更多信息，请参见私有数据体系结构参考。
初始化: 所有的链码需要包含一个初始化函数来初始化链码。默认情况下，这个函数永远不会执行。但是，您可以使用chaincode定义来请求Init函数是可调用的。如果请求执行Init，则fabric将确保在调用任何其他函数之前调用Init，并且只调用一次。
ESCC/VSCC插件: 自定义认证或验证插件的名称。

cli容器输入以下命令
```shell

peer lifecycle chaincode approveformyorg --tls true \
 --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
 --channelID mychannel --name mycc1 --version 1 --init-required --package-id mycc_1:aa699dad960f7244415b3133713bb5222657382e1694c926f175bf177f573737 --sequence 1 --waitForEvent

# --tls 是否启动tls
# --ca ca证书路径
# --channelID 智能合约安装通道
# --name 合约名
# --version 合约版本
# --package-id queryinstalled查询的合约ID
# --sequence 序列号
# --waitForEvent 等待peer提交交易返回
# --init-required 合约是否必须执行init
```

#### 检查合约定义是否满足策略
2.0的智能合约的部署必须满足一定合约定义策略，策略的定义在通道配置中具体定义
```shell

peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name mycc1  --version 1 --sequence 1 --output json --init-required
```
输出以下结果
```json
{
  "approvals": {
    "Org1MSP": true,
    "Org2MSP": false
  }
}
```
原因是lifecycle策略定义是满足过半数即可
这时候我们需要把Org2MSP也同意这个合约定义，切换环境变量为peer0.org2.example.com的配置

```shell

export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=peer0.org2.example.com:7051
```

以Org2MSP身份执行

``` shell

peer lifecycle chaincode install mycc1.tar.gz
peer lifecycle chaincode queryinstalled

# 注意: 显示所有安装的合约包，记录label为mycc1的 Package ID
```

```shell

peer lifecycle chaincode approveformyorg --tls true \
 --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
 --channelID mychannel --name mycc1 --version 1 --init-required --package-id mycc_1:aa699dad960f7244415b3133713bb5222657382e1694c926f175bf177f573737 --sequence 1 --waitForEvent

 peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name mycc1  --version 1 --sequence 1 --output json --init-required
```

输出以下结果
```json
{
  "approvals": {
    "Org1MSP": true,
    "Org2MSP": true
  }
}
```

#### 提交合约
在满足合约定义的策略后，可以提交合约
```shell

peer lifecycle chaincode commit -o orderer.example.com:7050 \
 --tls true --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
 --channelID mychannel --name mycc1 --peerAddresses peer0.org1.example.com:7051 \
 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
 --peerAddresses peer0.org2.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
 --version 1 --sequence 1 --init-required


# --tls 是否启动tls
# --ca ca证书路径
# --channelID 智能合约安装通道
# --name 合约名
# --version 合约版本
# --package-id queryinstalled查询的合约ID
# --sequence 序列号
# --waitForEvent 等待peer提交交易返回
# --init-required 合约是否必须执行init
# --peerAddresses 节点路径 
# --tlsRootCertFiles 节点ca根证书路径(--peerAddresses --tlsRootCertFiles  连用，可多个节点，多个节点即将合约部署到对应节点集合上)
```

查看docker容器会发现多了 dev-peerXXXXX容器（该容器是合约链码容器）

查看节点已提交合约
```shell

peer lifecycle chaincode querycommitted --channelID mychannel --name mycc1
```

输出内容
```shell

approvals: {
    Org1MSP: true,
    Org2MSP: true
}
```

#### 操作合约
fabric智能合约操作主要有invoke跟query,此处与1.x完全一致
初始化合约，执行init方法，设置a:100 b:100
```shell

 peer chaincode invoke -o orderer.example.com:7050 --tls true \
--cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
-C mychannel -n mycc1 --peerAddresses peer0.org1.example.com:7051 \
--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
--peerAddresses peer0.org2.example.com:7051 \
--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
--isInit -c '{"Args":["Init","a","100","b","100"]}'
```

控制台输出：
```shell

2020-04-20 09:18:48.685 UTC [chaincodeCmd] chaincodeInvokeOrQuery -> INFO 001 Chaincode invoke successful. result: status:200
```

查询a的余额
```shell

peer chaincode query -C mychannel -n mycc2 -c '{"Args":["query","a"]}'
```

输出值为100

调用 invoke方法， a ->b 转账20
```shell

peer chaincode invoke -o orderer.example.com:7050 --tls true \
--cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
-C mychannel -n mycc1 --peerAddresses peer0.org1.example.com:7051 \
--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
--peerAddresses peer0.org2.example.com:7051 \
--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt  \
-c  '{"Args":["invoke","a","b","20"]}' 
```

再次查询a时，输出为80

对应raft-4node-swarm代码已上传到git 
本文档参考 https://uzshare.com/view/825034 ,做了更详细的实践说明















