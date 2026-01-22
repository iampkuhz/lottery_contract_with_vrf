# 脚本说明

## queryBalances.js

查询 `participants.csv` 中每个地址的 ETH 余额，并生成 SQL UPDATE 语句用于更新数据库。

### 功能

- 读取 `data/participants.csv` 文件
- 使用 Ethereum JSON-RPC API 查询每个钱包地址的 ETH 余额
- 根据查询结果生成 UPDATE SQL 语句
- SQL 语句格式：根据 `wallet_address` 更新 `lottery_status` 为 `FINISHED`，`lottery_balance` 为对应地址的余额（**以 Wei 为单位**）
- 更新表为 `lottery_participants`
- 将所有 SQL 语句保存到 `data/update_balances.sql` 文件

### 使用方法

```bash
# 方式1：从 .env 文件读取 RPC_URL
source .env
node script/queryBalances.js

# 方式2：直接通过环境变量传入
RPC_URL=https://your-rpc-url.com node script/queryBalances.js
```

### 配置

**必须设置 `RPC_URL` 环境变量**，脚本会从环境变量中读取。

在 `.env` 文件中设置：
```bash
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
```

### 输出示例

```
开始查询 ETH 余额并生成 SQL 语句...

找到 102 个参与者

[1/102] 查询地址: 0xCa3aD53751A68a37b1822D720f3f036202a3E1Ba
  ✓ 余额: 4.271239431e-9 ETH (4271239431 Wei)
[2/102] 查询地址: 0xA1B2C3D4E5F6789012345678901234567890Ab01
  ✓ 余额: 0.000020648539566306 ETH (20648539566306 Wei)
...

=================================
查询完成！
成功: 102 个
失败: 0 个
SQL 文件已生成: /path/to/data/update_balances.sql
=================================
```

### 生成的 SQL 文件示例

```sql
-- 自动生成的 UPDATE SQL 语句
-- 生成时间: 2026-01-21T02:39:43.128Z
-- 成功查询: 102 个地址
-- 失败: 0 个地址

UPDATE lottery_participants SET lottery_status = 'FINISHED', lottery_balance = '4271239431' WHERE wallet_address = '0xCa3aD53751A68a37b1822D720f3f036202a3E1Ba';
UPDATE lottery_participants SET lottery_status = 'FINISHED', lottery_balance = '20648539566306' WHERE wallet_address = '0xA1B2C3D4E5F6789012345678901234567890Ab01';
...
```

### 注意事项

- **必须设置 RPC_URL 环境变量**，否则脚本会报错退出
- 脚本会在每次查询之间延迟 200ms，以避免 API 限流
- **余额以 Wei 为单位存储在 SQL 中**（1 ETH = 10^18 Wei）
- 控制台输出会同时显示 ETH 和 Wei 两种单位
- 生成的 SQL 文件会覆盖已存在的文件
- 使用的是 Node.js 内置模块（fs, path, https），无需安装额外依赖
- 生成的 SQL 文件可以直接在数据库中执行
