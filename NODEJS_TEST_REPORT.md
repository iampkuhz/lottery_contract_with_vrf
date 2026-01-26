# Node.js 脚本完整测试流程

## 概述

使用 Node.js 脚本成功完成了红包合约的完整流程测试，包括充值、参与者注册、抽奖、分配等步骤。

## 测试环境

- **网络**: Sepolia 测试网
- **RPC**: Alchemy
- **合约**: RedPacketVRF (VRF 版本)
- **VRF Wrapper**: Chainlink V2.5

## 测试流程

### 1. 生成测试数据

```bash
node generateTestData.js
```

- 生成 300 条参与者测试数据
- 包含随机生成的钱包地址和用户信息
- CSV 格式: `data/participants.csv`

**结果**: ✅ 301 行 (1 行标题 + 300 条数据)

### 2. 充值 ETH

```bash
node script/1_deposit_eth/deposit.js
```

**环境变量**: `RPC_URL`, `PRIVATE_KEY`, `RED_PACKET`, `DEPOSIT_AMOUNT`

**执行结果**:

```
发送者地址: 0xC6e8870B8FEd296b2B7036D95b778ae86eedE984
红包合约地址: 0x6014619e8BEB869E88aC581634832871C068F788
充值金额: 0.001 ETH
交易哈希: 0x9d08248a74b41bd9991513163e62de8afe3236214af4b0863282f49ba10378cd
区块号: 10124897
```

### 3. 批量注册参与者

```bash
node script/2_register_addresses/registerBatch.js
```

**环境变量**: `RPC_URL`, `PRIVATE_KEY`, `RED_PACKET`, `BATCH_SIZE`, `CSV_PATH`

**执行结果**:

- **批次数**: 10 批 (每批 30 条)
- **有效记录**: 300 条
- **跳过记录**: 0 条
- **成功批次**: 10/10

**样本交易**:

```
批次 1/10: 0x2004400d4385c1999aedb6d16cc837c9a65f7b58ac150e8bbfac4269e636c451
批次 2/10: 0x40c2c66a6af65a3277abd43eddef6eb41345f6c4834befa6b9f5e66492efa885
...
```

**Gas 消耗**: 每批约 ~2.2M gas

### 4. 发起 VRF 抽奖请求

```bash
node script/3_draw/requestDraw.js
```

**环境变量**: `RPC_URL`, `PRIVATE_KEY`, `RED_PACKET`, `MAX_VRF_FEE_WEI`

**执行结果**:

```
VRF Wrapper: 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1
回调 Gas 限制: 70000
随机数数量: 1
预估 VRF 费用: 0.0 ETH

交易哈希: 0xf73aaf0382dbf4c9d60782f4882dc643a6cd00b3caac4b3a83d353a9134a6047
区块号: 10125084
Request ID: 98050632025977917641825412246358311624696113165187577107082150033834479576992
```

**等待时间**: Chainlink VRF 回调约 3-5 分钟

### 5. 检查随机数状态

```bash
node -e "
const { ethers } = require('ethers');
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const redPacket = new ethers.Contract(process.env.RED_PACKET,
  ['function randomReady() view returns (bool)'],
  provider);
const ready = await redPacket.randomReady();
console.log('Random ready:', ready);
"
```

**状态变化**:

- 初始: `randomReady: false, drawInProgress: true`
- VRF 回调后: `randomReady: true, drawInProgress: true`

### 6. 分配红包

```bash
node script/3_draw/distribute.js
```

**环境变量**: `RPC_URL`, `PRIVATE_KEY`, `RED_PACKET`

**执行结果**:

```
随机数已就绪，可以进行分配
交易哈希: 0x99b579f54f2ea0bc2d57c0dc138dec4db38fd535e3cc620f227d968207b18ab4
区块号: 10125099

DrawCompleted 事件:
  Request ID: 98050632025977917641825412246358311624696113165187577107082150033834479576992
  总金额: 0.001765906201903861 ETH
  参与者数: 301
```

**Gas 消耗**: ~12.6M gas

## Node.js 脚本优势对比

| 方面         | Forge        | Node.js |
| ------------ | ------------ | ------- |
| **安装**     | forge 工具链 | npm     |
| **学习曲线** | 陡峭         | 平缓    |
| **调试**     | 复杂         | 容易    |
| **输出**     | 冗长         | 精简    |
| **跨平台**   | 依赖 Rust    | ✅ 通用 |
| **集成**     | 需要 FFI     | ✅ 原生 |
| **性能**     | 快           | 略慢    |

## 脚本文件清单

```
script/
├── 0_deploy_contract/
│   ├── deploy.js          # 部署合约
│   └── addAdmin.js        # 添加管理员
├── 1_deposit_eth/
│   └── deposit.js         # 充值 ETH
├── 2_register_addresses/
│   └── registerBatch.js   # 批量注册参与者
└── 3_draw/
    ├── requestDraw.js     # 发起 VRF 请求
    └── distribute.js      # 分配红包
```

## 依赖安装

```bash
npm install ethers dotenv csv-parse
```

## 环境变量配置 (.env)

```bash
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY=0x...
RED_PACKET=0x6014619e8BEB869E88aC581634832871C068F788
VRF_WRAPPER=0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1

# 可选
BATCH_SIZE=100
DEPOSIT_AMOUNT=0.001
MAX_VRF_FEE_WEI=200000000000000
CSV_PATH=data/participants.csv
FORCE_SUBMIT=0
```

## 测试总耗时

- **准备阶段**: ~2 分钟（部署、充值、注册）
- **VRF 等待**: ~3-5 分钟（Chainlink 响应）
- **分配阶段**: ~1 分钟
- **总计**: ~6-8 分钟

## 关键发现

1. ✅ Node.js 脚本可完全替代 Forge 脚本
2. ✅ CSV 解析和批处理更灵活
3. ✅ 错误处理和日志输出更清晰
4. ✅ 支持 FORCE_SUBMIT 模式容错处理
5. ⚠️ Forge 脚本使用 `vm.startBroadcast()` 不需要显式签名，Node.js 需要私钥直接签名

## 后续优化方向

1. 添加 TypeScript 类型支持
2. 实现进度持久化（中断恢复）
3. 支持并发交易提交
4. 集成 Web UI 前端交互
5. 添加实时价格监控和优化
