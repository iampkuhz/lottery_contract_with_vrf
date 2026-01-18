# LINK 充值要求

## 配置

- **callbackGasLimit**: 70,000
- **Chainlink Max Gas Price**: 500 gwei
- **网络**: Sepolia 测试网

## 需要充值多少 LINK？

### 计算方式

```
所需 LINK = (回调 Gas + 协调器开销) × Max Gas Price ÷ LINK/ETH 价格

= (70,000 + 100,000) × 500 gwei ÷ 0.0024 ETH/LINK
= 170,000 × 500 gwei ÷ 0.0024 ETH/LINK
= 0.085 ETH ÷ 0.0024 ETH/LINK
= 35.42 LINK
```

### 建议充值金额

**最低要求**: 35-40 LINK
**推荐充值**: 50 LINK

> 这是**预留金额**，不是实际消耗。Chainlink VRF 要求 Subscription 有足够余额应对最坏情况（500 gwei）。

### 实际成本

- **预期消耗**: 0.5-1 LINK/次（按正常 1-10 gwei gas price）
- **可用次数**: 50 LINK 可用 50-100 次抽奖
- **未用 LINK**: 自动保留在 Subscription 中供后续使用
