#!/usr/bin/env node

/**
 * 读取合约 Allocation 事件并生成中奖金额 SQL
 * 使用事件里的 amount 作为中奖金额（无论是否转账成功）
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// 配置
const SQL_OUTPUT_PATH = path.join(__dirname, '../../data/update_allocations.sql');
const RPC_URL = process.env.RPC_URL;
const RED_PACKET = process.env.RED_PACKET;
const FROM_BLOCK = process.env.FROM_BLOCK ? Number(process.env.FROM_BLOCK) : 0;
const TO_BLOCK = process.env.TO_BLOCK ? Number(process.env.TO_BLOCK) : null;

// Allocation(address indexed participant, uint256 amount, bool success)
const ALLOCATION_TOPIC0 = '0x713569d3f9f2579eed9b8cfa81c153510a6aabb75d14627b781afc964fd9bee5';

if (!RPC_URL) {
    console.error('错误: 未设置 RPC_URL 环境变量');
    process.exit(1);
}
if (!RED_PACKET) {
    console.error('错误: 未设置 RED_PACKET 环境变量');
    process.exit(1);
}

function rpcRequest(method, params) {
    return new Promise((resolve, reject) => {
        const url = new URL(RPC_URL);
        const postData = JSON.stringify({
            jsonrpc: '2.0',
            method,
            params,
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
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    if (response.error) {
                        reject(new Error(response.error.message));
                    } else {
                        resolve(response.result);
                    }
                } catch (error) {
                    reject(error);
                }
            });
        });

        req.on('error', (error) => reject(error));
        req.write(postData);
        req.end();
    });
}

function hexToNumber(hex) {
    return Number(BigInt(hex));
}

function toHexBlock(n) {
    return '0x' + n.toString(16);
}

function parseAddressFromTopic(topic) {
    return '0x' + topic.slice(26);
}

function parseAllocationData(data) {
    const hex = data.startsWith('0x') ? data.slice(2) : data;
    const amountHex = hex.slice(0, 64);
    const successHex = hex.slice(64, 128);
    const amount = BigInt('0x' + amountHex);
    const success = BigInt('0x' + successHex) !== 0n;
    return { amount, success };
}

async function getLatestBlock() {
    const hex = await rpcRequest('eth_blockNumber', []);
    return hexToNumber(hex);
}

function generateUpdateSQL(address, amountWei) {
    return `UPDATE lottery_participants SET lottery_status = 'FINISHED', lottery_balance = '${amountWei}' WHERE user_id = (SELECT user_id FROM lottery_participants WHERE LOWER(wallet_address) = LOWER('${address}') LIMIT 1);`;
}

async function main() {
    const toBlock = TO_BLOCK === null ? await getLatestBlock() : TO_BLOCK;
    console.log('开始读取 Allocation 事件并生成 SQL...\n');
    console.log(`合约: ${RED_PACKET}`);
    console.log(`区块范围: ${FROM_BLOCK} - ${toBlock}`);
    console.log('');

    const totals = new Map();
    let totalEvents = 0;
    let successEvents = 0;
    let failedEvents = 0;

    const logs = await rpcRequest('eth_getLogs', [{
        address: RED_PACKET,
        fromBlock: toHexBlock(FROM_BLOCK),
        toBlock: toHexBlock(toBlock),
        topics: [ALLOCATION_TOPIC0]
    }]);

    for (const log of logs) {
        totalEvents++;
        const participant = parseAddressFromTopic(log.topics[1]);
        const { amount, success } = parseAllocationData(log.data);
        const prev = totals.get(participant) || 0n;
        totals.set(participant, prev + amount);
        if (success) {
            successEvents++;
        } else {
            failedEvents++;
        }
    }

    console.log(`已处理区块 ${FROM_BLOCK} - ${toBlock}，累计事件 ${totalEvents}`);

    const sqlStatements = [];
    for (const [addr, amount] of totals.entries()) {
        sqlStatements.push(generateUpdateSQL(addr, amount.toString()));
    }

    const sqlContent = [
        '-- 自动生成的 UPDATE SQL 语句（基于 Allocation 事件）',
        `-- 生成时间: ${new Date().toISOString()}`,
        `-- 合约地址: ${RED_PACKET}`,
        `-- 区块范围: ${FROM_BLOCK}-${toBlock}`,
        `-- 事件总数: ${totalEvents}`,
        `-- 成功转账事件: ${successEvents}`,
        `-- 失败转账事件: ${failedEvents}`,
        '',
        ...sqlStatements
    ].join('\n');

    fs.writeFileSync(SQL_OUTPUT_PATH, sqlContent, 'utf-8');

    console.log('\n=================================');
    console.log('生成完成！');
    console.log(`参与者数量: ${totals.size}`);
    console.log(`SQL 文件已生成: ${SQL_OUTPUT_PATH}`);
    console.log('=================================\n');
}

main().catch((err) => {
    console.error('错误:', err.message);
    process.exit(1);
});
