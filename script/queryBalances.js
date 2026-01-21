#!/usr/bin/env node

/**
 * 查询 participants.csv 中每个地址的 ETH 余额
 * 生成 UPDATE SQL 语句用于更新数据库
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// 配置
const CSV_FILE_PATH = path.join(__dirname, '../data/participants.csv');
const SQL_OUTPUT_PATH = path.join(__dirname, '../data/update_balances.sql');
const RPC_URL = process.env.RPC_URL;

// 检查环境变量
if (!RPC_URL) {
    console.error('错误: 未设置 RPC_URL 环境变量');
    console.error('请在 .env 文件中设置 RPC_URL 或通过命令行传入:');
    console.error('  RPC_URL=https://your-rpc-url node script/queryBalances.js');
    process.exit(1);
}

// 解析 CSV
function parseCSV(content) {
    const lines = content.split('\n');
    const headers = lines[0].split(',');
    const rows = [];

    for (let i = 1; i < lines.length; i++) {
        if (!lines[i].trim()) continue;

        const values = lines[i].split(',');
        const row = {};
        headers.forEach((header, index) => {
            row[header.trim()] = values[index] ? values[index].trim() : '';
        });
        rows.push(row);
    }

    return { headers, rows };
}

// 查询 ETH 余额（使用 JSON-RPC）
async function getBalance(address) {
    return new Promise((resolve, reject) => {
        const url = new URL(RPC_URL);
        const postData = JSON.stringify({
            jsonrpc: '2.0',
            method: 'eth_getBalance',
            params: [address, 'latest'],
            id: 1
        });

        const options = {
            hostname: url.hostname,
            port: url.port || 443,
            path: url.pathname + url.search,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
            }
        };

        const req = https.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    if (response.error) {
                        reject(new Error(response.error.message));
                    } else {
                        // 返回 Wei 和 ETH 两种单位
                        const balanceWei = BigInt(response.result);
                        const balanceEth = Number(balanceWei) / 1e18;
                        resolve({
                            wei: balanceWei.toString(),
                            eth: balanceEth
                        });
                    }
                } catch (error) {
                    reject(error);
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        req.write(postData);
        req.end();
    });
}

// 延迟函数（避免 API 限流）
function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// 生成 UPDATE SQL 语句（使用 Wei 单位）
function generateUpdateSQL(address, balanceWei) {
    return `UPDATE lottery_participants SET lottery_status = 'FINISHED', lottery_balance = '${balanceWei}' WHERE wallet_address = '${address}';`;
}

// 主函数
async function main() {
    try {
        console.log('开始查询 ETH 余额并生成 SQL 语句...\n');

        // 读取 CSV 文件
        const csvContent = fs.readFileSync(CSV_FILE_PATH, 'utf-8');
        const { rows } = parseCSV(csvContent);

        console.log(`找到 ${rows.length} 个参与者\n`);

        const sqlStatements = [];
        let successCount = 0;
        let failCount = 0;

        // 遍历每一行，查询余额
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            const address = row.wallet_address;

            if (!address || address === '') {
                console.log(`[${i + 1}/${rows.length}] 跳过：无地址`);
                failCount++;
                continue;
            }

            try {
                console.log(`[${i + 1}/${rows.length}] 查询地址: ${address}`);

                // 查询余额
                const balance = await getBalance(address);

                // 生成 SQL 语句（使用 Wei）
                const sql = generateUpdateSQL(address, balance.wei);
                sqlStatements.push(sql);

                console.log(`  ✓ 余额: ${balance.eth} ETH (${balance.wei} Wei)`);
                successCount++;

                // 延迟 200ms，避免 API 限流
                await delay(200);

            } catch (error) {
                console.error(`  ✗ 查询失败: ${error.message}`);
                failCount++;
            }
        }

        // 写入 SQL 文件
        const sqlContent = [
            '-- 自动生成的 UPDATE SQL 语句',
            `-- 生成时间: ${new Date().toISOString()}`,
            `-- 成功查询: ${successCount} 个地址`,
            `-- 失败: ${failCount} 个地址`,
            '',
            ...sqlStatements
        ].join('\n');

        fs.writeFileSync(SQL_OUTPUT_PATH, sqlContent, 'utf-8');

        console.log('\n=================================');
        console.log('查询完成！');
        console.log(`成功: ${successCount} 个`);
        console.log(`失败: ${failCount} 个`);
        console.log(`SQL 文件已生成: ${SQL_OUTPUT_PATH}`);
        console.log('=================================\n');

    } catch (error) {
        console.error('错误:', error.message);
        process.exit(1);
    }
}

// 运行
main();
