# 红包合约（Chainlink VRF v2.5）

> 说明：本文档与代码注释均为中文，便于团队理解与维护。

## 功能与约束
- 任意地址可向合约充值 ETH 作为奖池。
- 管理员批量录入参与者：`user_id -> wallet_address` 映射（仅允许 EOA，合约地址会被拒绝）。
- 管理员可随时发起 `requestDraw()`；一旦请求发起，参与者列表即封存（`drawInProgress == true`），需完成本轮分配后才允许修改。
- VRF 使用 v2.5 Wrapper Direct Funding（原生币支付）。
- 分配算法为“随机权重 + 头奖保底”：权重取哈希高位并平方放大，头奖至少占 `minTopBps`。
- 每位参与者都会触发 `Allocation` 事件（包含 `amount` 与 `success`）；转账失败的金额留在合约中，可由管理员后续处理。

## 关键常量与状态
- VRF 固定参数：`requestConfirmations=3`、`callbackGasLimit=70000`、`numWords=1`、`useNativePayment=true`。
- 分配参数：`minTopBps=500`（头奖最小占比 5%）、`weightBits=16`。
- 抽奖状态：`drawInProgress`、`randomReady`、`lastRequestId`、`lastRandomWord`。

## 项目结构
- `src/RedPacketVRF.sol`：主合约
- `src/IRedPacketVRF.sol`：接口与事件
- `script/0_deploy_contract/Deploy.s.sol`：部署脚本
- `script/1_deposit_eth/Deposit.s.sol`：充值脚本
- `script/2_register_addresses/RegisterBatch.s.sol`：批量录入脚本（CSV）
- `script/2_register_addresses/GenerateCastRegisterCommands.s.sol`：生成 cast 批量录入命令
- `script/3_draw/RequestDraw.s.sol`：发起抽奖请求脚本
- `script/3_draw/Distribute.s.sol`：触发分配脚本
- `script/3_draw/_QuoteVrfFee.s.sol`：查询 VRF 费用脚本
- `script/4_export_to_1d/queryAllocations.js`：导出 Allocation 事件并生成 SQL
- `test/RedPacketVRF.t.sol`：Foundry 测试

## 环境变量（.env）
> 建议从 `.env.example` 复制后修改。

```bash
# RPC（脚本与 cast 交互使用）
RPC_URL=https://sepolia.infura.io/v3/xxxxx

# 钱包私钥（部署/交互脚本使用）
PRIVATE_KEY=your_private_key

# VRF v2.5（Wrapper 地址见 README）
VRF_WRAPPER=0x0000000000000000000000000000000000000000
# 发起抽奖时的 VRF 费用上限（wei，可选）
MAX_VRF_FEE_WEI=2000000000000000

# 录入批次参数（RegisterBatch 脚本使用）
RED_PACKET=deployed_contract_address
# 每批录入数量（设置为 0 启用自动估算批次，需 --ffi）
BATCH_SIZE=30
# 强制提交：1=跳过不合法地址并继续；0/不设置=遇错即停止
FORCE_SUBMIT=0
# CSV 文件路径（可选，默认 data/participants.csv）
CSV_PATH=data/participants.csv

# 充值金额（Deposit 脚本使用，默认 0.001 ETH）
DEPOSIT_AMOUNT=0.001ether

# 导出 Allocation 事件参数（queryAllocations.js 使用）
# FROM_BLOCK 为起始区块；TO_BLOCK 不设置则默认最新区块
FROM_BLOCK=0
# TO_BLOCK=0
```

## CSV 格式与映射
- csv 文件从云端下载后放在本地读取，用于 RegisterBatch 脚本使用
- 样例文件：`data/participants.sample.csv`
- 默认读取：`data/participants.csv`
- CSV 表头：
  `id,user_id,user_name,user_avatar,wallet_address,wallet_type,created_at,updated_at,lottery_entered,lottery_status,lottery_balance,message`
- 映射规则：
  - `employeeId = user_id`
  - `participant = wallet_address`

## 使用流程（脚本）
> 所有脚本示例均默认：`set -a; source .env; set +a`

### 1) 部署合约
```bash
forge script script/0_deploy_contract/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

部署完成后，将合约地址写入 `.env` 文件，并重新加载环境变量

推荐执行下面脚本，在 etherscan 上完成合约验证，方便后续查看合约状态：

```bash
forge verify-contract --show-standard-json-input 0x0000000000000000000000000000000000000000 src/RedPacketVRF.sol:RedPacketVRF > ~/Downloads/tmp.json
```

### 2) 批量录入参与者（CSV）

先从服务端将用户注册好的 `participants.csv` 文件放到项目的对应路径，然后执行 script脚本：

```bash
time forge script script/2_register_addresses/RegisterBatch.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```
- 若 `BATCH_SIZE=0`，会自动估算批次大小，请加 `--ffi`。
- 若仅需生成 `cast send` 命令（不发送交易）：
```bash
forge script script/2_register_addresses/GenerateCastRegisterCommands.s.sol
```

注册完成后，可以在 etherscan 上 `Read Contract` 看到已经注册的地址列表

回到后台系统，执行 `Verify Contract Data` 按钮，会读取链上的地址状态，并更新数据库的状态为 `Address Registered`

### 3) 充值奖池
可以执行 cast 命令充值，也可以执行 forge 脚本:

```bash
cast send $RED_PACKET --value 0.5ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

```bash
forge script script/1_deposit_eth/Deposit.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

中间有多次充值时，可以多次执行。每次执行完成后，需要回后台系统，输入 交易hash、工号、姓名，让后台系统维护每个注资人的信息，在首页展示

### 4) 发起抽奖请求（VRF）
```bash
forge script script/3_draw/RequestDraw.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --ffi
```
- 脚本会查询 gas price 并估算 VRF 费用，超过 `MAX_VRF_FEE_WEI` 会中止。
- 一般来说，发起后1min，就会回调填充 随机数。可以查询 etherscan 网页看到随机数是否已经写回到合约 
- 在执行 `RequestDraw` 之前，可以查询当前要支付的 vrf 费用:
```bash
forge script script/3_draw/_QuoteVrfFee.s.sol --fork-url $RPC_URL --ffi
```

### 5) VRF 回调完成后触发分配

确认 随机数 已经写回到合约后，执行 `Distribute()` 函数，计算每个用户的红包金额并直接完成转账：

```bash
forge script script/3_draw/Distribute.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

如果部分地址转账失败（比如不允许接受原生代币的合约地址），金额留在合约中


## 导出 Allocation 事件并生成 SQL

一般来说， 在后台系统执行 Update User Balances 按钮，输入 `Distribute` 的交易hash，就会自动更新。如果出现异常，没有正常更新，可以执行下面的脚本，生成更新每个用户红包金额的 sql：

> 脚本：`script/4_export_to_1d/queryAllocations.js`

```bash
node script/4_export_to_1d/queryAllocations.js
```

> ![IMPORTANT]
> 这个脚本并不会更新后台 `Winner List` 中关联的合约地址，注意要手动更新后台

## 常用查询命令（cast）
```bash
# 查询随机数是否就绪
cast call $RED_PACKET "randomReady()(bool)" --rpc-url $RPC_URL

# 查询是否处于抽奖中
cast call $RED_PACKET "drawInProgress()(bool)" --rpc-url $RPC_URL

# 获取参与者映射
cast call $RED_PACKET "getParticipantAddressMapping()(uint256[],address[])" --rpc-url $RPC_URL
```

## 关键接口速览
- 参与者批量录入：`setParticipantsBatch(uint256[] employeeIds, address[] participants)`
- 发起抽奖请求：`requestDraw()`
- 预估 VRF 费用：`getRequestPriceNative()`
- 管理员触发分配：`distribute()`
- 管理员紧急提现：`emergencyWithdraw(address to, uint256 amount)`

## 注意事项
- 参与者录入时会拒绝合约地址，仅允许 EOA（`code.length == 0`）。
- 发起 `requestDraw()` 后参与者列表不可修改，需完成分配后再进行变更。
- 抽奖前确保合约已充值，且参与者列表不为空。
- 转账失败的金额会留在合约中，可由管理员后续处理。
