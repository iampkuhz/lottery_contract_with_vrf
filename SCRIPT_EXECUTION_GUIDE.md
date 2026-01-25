# 红包合约脚本执行步骤

## 执行顺序

```
环境准备 → 合约部署 → VRF配置 → 数据准备 → 参与者录入 → 充值奖池 → 发起抽奖 → 触发分配 → 结果查看 → 数据更新
```

## 执行步骤

### 1. 环境准备

```bash
# 设置代理
export https_proxy=socks5h://127.0.0.1:13659
export http_proxy=socks5h://127.0.0.1:13659

# 安装 Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 安装依赖
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts

# 配置 .env
set -a; source .env; set +a
```

### 2. VRF 订阅配置

1. 访问 [Chainlink VRF Subscription Manager](https://vrf.chain.link)
2. 创建订阅并记录 `SUB_ID`
3. 充值 LINK 代币（至少 2 LINK）
4. 更新 `.env` 文件中的 `SUB_ID`

### 3. 合约部署

```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

### 4. 添加 Consumer

在 VRF Subscription Manager 中将部署的合约地址添加为 Consumer

### 4. 数据准备

```bash
# 可选：生成测试数据
forge script script/TestGenerateParticipantsCsv.s.sol
```

### 5. 参与者录入

```bash
forge script script/RegisterBatch.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

### 6. 充值奖池

```bash
forge script script/Deposit.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

### 7. 发起抽奖

```bash
forge script script/RequestDraw.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

### 8. 触发分配

```bash
forge script script/Distribute.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

### 9. 结果查看

```bash
forge script script/ShowAllocations.s.sol --rpc-url $RPC_URL -vvv
```

### 10. 数据更新

```bash
forge script script/UpdateCsvWithAllocations.s.sol --rpc-url $RPC_URL --ffi -vvv
```
