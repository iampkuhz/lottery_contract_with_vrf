# 红包合约（Chainlink VRF）

> 说明：本文档与代码注释均为中文，便于团队理解与维护。

## 功能概述
- 任何人都可向合约充值 ETH（红包资金池）。
- 参与抽奖的人由管理员录入：`工号 -> 地址` 的映射，支持批量录入，约 200 人规模。
- 管理员随时发起抽奖请求，通过 Chainlink VRF v2.5 Direct Funding（Wrapper）获取随机数。
- 合约基于随机数生成权重并分配金额，直接转账给每位参与者。
- 若转账失败，自动记入 `pendingClaims`，参与者可自行领取（兜底处理）。
- 管理员支持列表与紧急提现（兜底处理）。

## 项目结构
- `src/RedPacketVRF.sol`：主合约
- `test/RedPacketVRF.t.sol`：Foundry 测试
- `foundry.toml`：Foundry 配置

## 核心流程
1. 管理员批量录入参与者：`setParticipantsBatch(ids, addrs)`
2. 任意地址向合约充值 ETH
3. 管理员发起抽奖：`requestDraw()`
4. VRF 回调 `rawFulfillRandomWords` 写入随机数
5. 管理员触发分配：`distribute()`

## 使用方式（Foundry）

### 1. 安装 Foundry（若未安装）
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 运行测试
```bash
forge test -vvv
```

### 依赖安装
```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```

## Sepolia 部署与交互（脚本）

> 说明：本合约使用 Chainlink VRF v2.5 Direct Funding（Wrapper）模式，无需订阅；具体网络参数以官方文档为准。

### .env 示例（放在仓库根目录）
```bash
# RPC
RPC_URL=https://sepolia.infura.io/v3/xxxxx

# 钱包
PRIVATE_KEY=你的私钥

# VRF（Direct Funding，Wrapper 地址见下方）
VRF_WRAPPER=0x0000000000000000000000000000000000000000
# 发起抽奖时的 VRF 费用上限（wei）
MAX_VRF_FEE_WEI=5000000000000000

# 录入批次参数
RED_PACKET=合约地址
BATCH_SIZE=30
```

### 参与者 CSV 文件
- 样例文件：`data/participants.sample.csv`
- 真实文件：`data/participants.csv`（已加入 .gitignore）

### 测试用两列 CSV（工号,地址）
- 测试文件：`data/id_address.test.csv`（已加入 .gitignore）
- 生成命令：见 `script/TestGenerateParticipantsCsv.s.sol` 顶部注释

### 1) 准备环境变量
```bash
export RPC_URL="https://sepolia.infura.io/v3/xxxxx"
export PRIVATE_KEY="你的私钥"
export VRF_WRAPPER="0x0000000000000000000000000000000000000000"
export MAX_VRF_FEE_WEI=5000000000000000
```
> `VRF_WRAPPER` 请从 Chainlink 官方文档的 VRF v2.5 Supported Networks 页面获取。
```text
source: https://docs.chain.link/vrf/v2-5/supported-networks
```

### 2) 准备 VRF 费用（Direct Funding）
合约会用原生币支付 VRF 请求费用（从奖池中扣），建议在发起 `requestDraw()` 前通过 `getRequestPriceNative()` 估算费用，并在脚本中设置 `MAX_VRF_FEE_WEI` 作为上限保护。
```text
source: https://docs.chain.link/vrf/v2-5/direct-funding
```

### 3) 部署合约
见 `script/Deploy.s.sol` 顶部注释。

### 4) 录入参与者（每 30 人一批）
见 `script/RegisterBatch.s.sol` 顶部注释。

### 5) 充值奖池
```bash
cast send $RED_PACKET --value 0.1ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 6) 发起抽奖请求
见 `script/RequestDraw.s.sol` 顶部注释（会自动查询 gas price、估算费用并检查 `MAX_VRF_FEE_WEI` 上限，需 `--ffi`）。

### 7) VRF 回调完成后触发分配
等待 VRF 回调完成（可通过 `randomReady()` 查看），然后执行：见 `script/Distribute.s.sol` 顶部注释。

### VRF v2.5 Supported Networks
```text
source: https://docs.chain.link/vrf/v2-5/supported-networks
```

### 运行样例（Sepolia）
流程命令写在各脚本文件顶部注释中。

## 测试流程说明（需与测试同步更新）
> 说明：以下流程以 `test/RedPacketVRF.t.sol` 为准，后续修改测试逻辑时请同步更新本节。

### setUp()
1. 部署 `VRFV2PlusWrapperMock`（本地 VRF Wrapper mock）。
2. 部署 `RedPacketVRF`，构造参数 `_vrfWrapper = address(wrapper)`。
3. `addAdmin(admin)`：由 owner 添加管理员。

### testBatchSetParticipantsAndDraw()
1. `setParticipantsBatch([101,102,103], [user1,user2,user3])`：由 `admin` 批量录入参与者。
2. 向合约转账 `3 ether`（触发 `receive`）。
3. `requestDraw()`：由 `admin` 发起抽奖，返回 `requestId`。
4. `fulfillRandomWords(requestId, address(redPacket), 123456)`：由 mock 回调 VRF。
5. 断言：`drawInProgress == false`，合约余额为 `0`。

### testRejectContractParticipant()
1. 部署 `RevertingReceiver`（合约地址）。
2. `setParticipantsBatch([201], [bad])`：由 `admin` 录入。
3. 断言调用会回退：`ContractNotAllowed`。

### testRegister200AndDrawWithGasLogs()
1. 每 30 人一批次调用 `setParticipantsBatch(ids, addrs)` 录入 200 名参与者。
2. 调用 `getParticipantAddressMapping()` 校验 200 名参与者工号与地址映射。
3. 向合约转账 `0.1 ether`（触发 `receive`）。
4. `requestDraw()`：由 `admin` 发起抽奖，返回 `requestId`。
5. `fulfillRandomWords(requestId, address(redPacket), 20260117)`：由 mock 回调 VRF。
6. `distribute()`：由 `admin` 触发分配。
7. `getParticipantAmountMapping()` 校验 200 名参与者分配金额映射。
8. 打印统计：最大/最小/总和余额；并断言 `sum == 0.1 ether`。

### testGasRawFulfillRandomWords()
1. 录入 1 名参与者并充值 `0.01 ether`。
2. `requestDraw()` 获取 `requestId`。
3. 以 `wrapper` 身份调用 `rawFulfillRandomWords`，输出 gas 消耗日志。

## Fork 测试流程说明（需与测试同步更新）
> 说明：以下流程以 `test/RedPacketVRF.fork.t.sol` 为准，需配置 `RPC_URL` 与 `VRF_WRAPPER`；未配置时测试会自动跳过，便于流水线运行。

### testForkRequestPriceNativeAndBalanceDelta()
1. 使用 `RPC_URL` 与 `VRF_WRAPPER` 创建 fork。
2. 部署 `RedPacketVRF` 并录入 1 名参与者。
3. 充值 `5 ether`，调用 `getRequestPriceNative()` 获取预估费用。
4. 发起 `requestDraw()`，断言合约余额减少等于预估费用。

### 常用交互命令（cast）
```bash
# 查询随机数是否已就绪
cast call $RED_PACKET "randomReady()(bool)" --rpc-url $RPC_URL

# 管理员发起抽奖（费用从奖池扣，脚本内校验 MAX_VRF_FEE_WEI 上限）
cast send $RED_PACKET "requestDraw()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# 管理员触发分配（randomReady 为 true 后）
cast send $RED_PACKET "distribute()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

## 合约关键接口
- 参与者批量录入：`setParticipantsBatch(uint256[] employeeIds, address[] participants)`
- 发起抽奖请求：`requestDraw()`（可选携带 `value` 支付 VRF 费用）
- 预估 VRF 费用：`getRequestPriceNative()`
- 管理员触发分配：`distribute()`
- 兜底领取：`claimPending()`
- 管理员紧急提现：`emergencyWithdraw(address to, uint256 amount)`

## 注意事项
- 真实环境需使用 Chainlink VRF v2.5 的正确 `wrapper` 地址配置。
- 参与者录入时会拒绝合约地址，仅允许 EOA（`code.length == 0`）。
- 抽奖前确保合约已充值，且参与者列表不为空。
- 分配算法为“随机权重 + 头奖保底”，权重取哈希高位并平方放大，头奖至少占 `minTopBps`。
- 仅管理员可发起抽奖与配置参数。
