# 菲皮 操作记录

## 0118 vrf 版本使用错误
1. 之前代码使用 vrf2，应该使用 vrf2.5，sub_id 从 uin64 转变成 uint256
2. 重新调整后重新部署红包合约 0x2BECA3781eeFB271Fe4784bEB293e674F316BfF6
3. 使用 emergencyWithdraw 把 eth 直接从 0x2BECA3781eeFB271Fe4784bEB293e674F316BfF6 转到新的红包合约 0x2BECA3781eeFB271Fe4784bEB293e674F316BfF6


# 工具命令

```bash
生成 json 文件，在etherscan 上完成合约 verify
forge verify-contract --show-standard-json-input 0x0000000000000000000000000000000000000000 src/RedPacketVRF.sol:RedPacketVRF > tmp.json
```