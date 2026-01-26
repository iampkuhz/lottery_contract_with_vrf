# 菲皮 操作记录

## 0124 合约切换到事件驱动，不再记录 storage

## 0122 vrf Direct Funding
1. 切换到 Direct Funding 重新部署

## 0118-3 vrf 配置错误
1. 本地没有使用 v2.5 的 合约地址，环境变量没更新，重新部署一个合约

## 0118-2 添加合约接口
1. add getParticipantAmountMapping and getParticipantAddressMapping 

## 0118-1 vrf 版本使用错误
1. 之前代码使用 vrf2，应该使用 vrf2.5，sub_id 从 uin64 转变成 uint256
2. 重新调整后重新部署红包合约 0x2BECA3781eeFB271Fe4784bEB293e674F316BfF6
3. 使用 emergencyWithdraw 把 eth 直接从 0x2BECA3781eeFB271Fe4784bEB293e674F316BfF6 转到新的红包合约 0x2BECA3781eeFB271Fe4784bEB293e674F316BfF6



# 工具命令

```bash
#生成 json 文件，在etherscan 上完成合约 verify
forge verify-contract --show-standard-json-input 0x0000000000000000000000000000000000000000 src/RedPacketVRF.sol:RedPacketVRF > ~/Downloads/tmp.json

#从老合约中吧 eth 转移给新合约
cast send $RED_PACKET "emergencyWithdraw(address,uint256)" 0xYourToAddress 0.05ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL

#给合约地址转账
cast send 0xRedPacket --value 0.5ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```