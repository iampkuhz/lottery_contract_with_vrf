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
