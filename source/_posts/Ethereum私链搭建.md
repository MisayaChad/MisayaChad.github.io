---
title: Ethereum私链搭建
date: 2017-08-04 10:20:11
categories: Ethereum
---

#### 安装go-ethereum
refrence: https://github.com/ethereum/go-ethereum
&emsp;&emsp;&emsp;&emsp;&ensp;&ensp; https://github.com/ethereum/go-ethereum/wiki/Building-Ethereum

#### 预先分配以太币余额到你的帐户
1. create new account
``` shell
/Users/chad/go-ethereum/build/bin/geth --identity "MyNodeName" --rpc --rpcaddr 0.0.0.0 --rpcport "9660" --rpccorsdomain "*" --datadir "/Users/chad/go-ethereum/chains/TestChains" --port "30303" --rpcapi "db,eth,net,web3" --networkid 1999 account new
```
2. get account address
``` shell
/Users/chad/go-ethereum/build/bin/geth --identity "MyNodeName" --rpc --rpcaddr 0.0.0.0 --rpcport "9660" --rpccorsdomain "*" --datadir "/Users/chad/go-ethereum/chains/TestChains" --port "30303" --rpcapi "db,eth,net,web3" --networkid 1999 account list
```

3. Add the following command to your CustomGenesis.json file
``` json
{
"config": {
        "chainId": 1999,
        "homesteadBlock": 0,
        "eip155Block": 0,
        "eip158Block": 0
    },
    "nonce": "0x0000000000000042",     "timestamp": "0x0",
    "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "extraData": "",     "gasLimit": "0x8000000",     "difficulty": "0x400",
    "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "coinbase": "0x0000000000000000000000000000000000000000",     "alloc": {"6e710a4a8dc46c2e5053c9da64dee8f2206c9d3e":{"balance": "90000000000000000000"}     }
}
```

NOTE:

``` shell
"alloc": {"此处填写你的账户地址":{"balance": "90000000000000000000"}
使用中发现extraData不为空时，会报错
Fatal: invalid genesis file: json: cannot unmarshal hex string without 0x prefix into Go struct field Genesis.extraData of type hexutil.Bytes

Attention: chainId不能为0，为0时，在后续转账是无法成功。报错
Error: insufficient funds for gas * price + value

Attention: chainId 和 后续的networkid 保持一致，否则报错Error: insufficient funds for gas * price + value。
```

refrence: http://www.ethdocs.org/en/latest/network/test-networks.html#setting-up-a-local-private-testnet

4. init project
``` shell
/Users/chad/go-ethereum/build/bin/geth --identity "MyNodeName" --rpc --rpcaddr 0.0.0.0 --rpcport "9660" --rpccorsdomain "*" --datadir "/Users/chad/go-ethereum/chains/TestChains" --port "30303" --rpcapi "db,eth,net,web3" --networkid 1999 init CustomGenesis.json
```
5. run project to console
``` shell
/Users/chad/go-ethereum/build/bin/geth --identity "MyNodeName" --rpc --rpcaddr 0.0.0.0 --rpcport "9660" --rpccorsdomain "*" --datadir "/Users/chad/go-ethereum/chains/TestChains" --port "30303" --rpcapi "db,eth,net,web3" --networkid 1999 console
```
6. create new account for coinbase（aconsole inner）
``` java
personal.newAccount("123")  //123为密码
personal.listAccounts //账户地址列表
user1 =personal.listAccounts[1] //拿到创建的账户地址
eth.getBalance(user1) //获取账户余额
eth.blockNumber //获取当前区块数
miner.setEtherbase(personal.listAccounts[1]) //设置矿工账户
miner.start() //开始挖矿
```
7. open othen cmd
``` java
//再开一个终端，衔接上个终端中的数据
/Users/chad/go-ethereum/build/bin/geth --identity "MyNodeName" --rpc --rpcaddr 0.0.0.0 --rpcport "9660" --rpccorsdomain "*" --datadir "/Users/chad/go-ethereum/chains/TestChains" --port "30303" --rpcapi "db,eth,net,web3" --networkid 1999 attach
```
8. transaction
``` java
personal.newAccount("123")  //123为密码
personal.listAccounts //账户地址列表
user2 =personal.listAccounts[2] //拿到刚刚创建的账户地址，该账户作为交易接受账户
user0 =personal.listAccounts[0] //拿到初始的账户地址
personal.unlockAccount(user0) //解锁该账户，发起交易者必须解锁账户
eth.sendTransaction({from:user0,to:user2,value:web3.toWei(1,"ether")}) //转账
eth.getBalance(user2) //获取账户余额
```
NOTE: 本教程开启一个终端挖矿，另一个终端进行操作。以太坊主网上也是会一直进行挖矿，因为交易要记录在通过挖矿找到的块上才算生效