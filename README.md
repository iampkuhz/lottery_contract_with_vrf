# 红包合约（Chainlink VRF）

> 说明：本文档与代码注释均为中文，便于团队理解与维护。

## 功能概述
- 任何人都可向合约充值 ETH（红包资金池）。
- 参与抽奖的人由管理员录入：`工号 -> 地址` 的映射，支持批量录入，约 200 人规模。
- 到达指定时间后，管理员发起抽奖请求，通过 Chainlink VRF 获取随机数。
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

> 说明：Chainlink 文档建议使用 VRF v2.5（v2 已被 v2.5 取代），订阅可在 VRF Subscription Manager 创建；具体网络参数以官方文档/控制台为准。

### .env 示例（放在仓库根目录）
```bash
# RPC
RPC_URL=https://sepolia.infura.io/v3/xxxxx

# 钱包
PRIVATE_KEY=你的私钥

# VRF（Sepolia / Mainnet 参考值见下方）
VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
KEY_HASH=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
SUB_ID=你的订阅ID

# 录入批次参数
RED_PACKET=合约地址
COUNT=200
BATCH_SIZE=30
START_ID=1000
BASE_ADDRESS=4096
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
export VRF_COORDINATOR="0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625"
export KEY_HASH="0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c"
export SUB_ID="你的订阅ID"
```
> 上述 `VRF_COORDINATOR` / `KEY_HASH` 为 Sepolia VRF v2 示例参数，来自 Chainlink 官方文档的 V2 Subscription Supported Networks 页面：
```text
source: https://docs.chain.link/vrf/v2/subscription/supported-networks
```

### 2) 创建并充值 VRF 订阅
1. 在 VRF Subscription Manager 创建订阅（Sepolia）。
2. 为订阅充值 LINK（确保有足够余额）。
```text
source: https://docs.chain.link/vrf/v2-5/subscription/create-manage
```

### 3) 部署合约
见 `script/Deploy.s.sol` 顶部注释。

### 4) 添加合约为订阅的 Consumer
在 VRF Subscription Manager 将部署后的合约地址添加为 Consumer。
```text
source: https://docs.chain.link/vrf/v2-5/subscription/create-manage
```

### 5) 录入参与者（每 30 人一批）
见 `script/RegisterBatch.s.sol` 顶部注释。

### 6) 充值奖池
```bash
cast send $RED_PACKET --value 0.1ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 7) 发起抽奖请求
见 `script/RequestDraw.s.sol` 顶部注释。

### 8) VRF 回调完成后触发分配
等待 VRF 回调完成（可通过 `randomReady()` 查看），然后执行：见 `script/Distribute.s.sol` 顶部注释。

### Sepolia / Mainnet 参数参考（VRF v2, Subscription）
> 以下为 Chainlink 官方文档提供的 VRF v2 subscription 参数示例（本合约接口为 v2）。

**Sepolia**
```
VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
KEY_HASH=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c  # 750 gwei
source: https://docs.chain.link/vrf/v2/subscription/supported-networks
```

**Ethereum Mainnet**
```
VRF_COORDINATOR=0x271682DEB8C4E0901D1a1550aD2e64D568E69909
KEY_HASH=0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef  # 200 gwei
# 500 gwei: 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92
# 1000 gwei: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805
source: https://docs.chain.link/vrf/v2/subscription/supported-networks
```

**VRF v2.5 Supported Networks**
```
source: https://docs.chain.link/vrf/v2-5/supported-networks
```

### 运行样例（Sepolia）
流程命令写在各脚本文件顶部注释中。

## 测试流程说明（需与测试同步更新）
> 说明：以下流程以 `test/RedPacketVRF.t.sol` 为准，后续修改测试逻辑时请同步更新本节。

### setUp()
1. 部署 `VRFCoordinatorV2Mock`（本地 VRF mock）。
2. 部署 `RedPacketVRF`，构造参数 `_vrfCoordinator = address(coordinator)`、`_keyHash = bytes32("key")`、`_subId = 1`。
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
2. 向合约转账 `0.1 ether`（触发 `receive`）。
3. `requestDraw()`：由 `admin` 发起抽奖，返回 `requestId`。
4. `fulfillRandomWords(requestId, address(redPacket), 20260117)`：由 mock 回调 VRF。
5. `distribute()`：由 `admin` 触发分配。
6. 打印统计：最大/最小/总和余额；并断言 `sum == 0.1 ether`。

### 常用交互命令（cast）
```bash
# 查询随机数是否已就绪
cast call $RED_PACKET "randomReady()(bool)" --rpc-url $RPC_URL

# 管理员发起抽奖
cast send $RED_PACKET "requestDraw()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# 管理员触发分配（randomReady 为 true 后）
cast send $RED_PACKET "distribute()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

## 合约关键接口
- 参与者批量录入：`setParticipantsBatch(uint256[] employeeIds, address[] participants)`
- 发起抽奖请求：`requestDraw()`
- 管理员触发分配：`distribute()`
- 兜底领取：`claimPending()`
- 管理员紧急提现：`emergencyWithdraw(address to, uint256 amount)`

## 注意事项
- 真实环境需使用 Chainlink VRF V2 的正确 `coordinator/keyHash/subId` 配置。
- 参与者录入时会拒绝合约地址，仅允许 EOA（`code.length == 0`）。
- 抽奖前确保合约已充值，且参与者列表不为空。
- 分配算法为“随机权重 + 头奖保底”，权重取哈希高位并平方放大，头奖至少占 `minTopBps`。
- 仅管理员可发起抽奖与配置参数。
