#!/usr/bin/env node

/**
 * 查询 participants.csv 中每个地址的 ETH 余额
 * 并更新 lottery_balance 和 lottery_status 字段
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// 配置
const CSV_FILE_PATH = path.join(__dirname, '../data/participants.csv');
const RPC_URL = process.env.RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/z1-dhbKC_Gr2bytop6A1U';

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

// 生成 CSV
function generateCSV(headers, rows) {
  const lines = [headers.join(',')];
  
  rows.forEach(row => {
    const values = headers.map(header => row[header] || '');
    lines.push(values.join(','));
  });
  
  return lines.join('\n');
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
            // 将 Wei 转换为 ETH
            const balanceWei = BigInt(response.result);
            const balanceEth = Number(balanceWei) / 1e18;
            resolve(balanceEth);
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

// 主函数
async function main() {
  try {
    console.log('开始查询 ETH 余额...\n');
    
    // 读取 CSV 文件
    const csvContent = fs.readFileSync(CSV_FILE_PATH, 'utf-8');
    const { headers, rows } = parseCSV(csvContent);
    
    console.log(`找到 ${rows.length} 个参与者\n`);
    
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
        
        // 更新字段
        row.lottery_balance = balance.toFixed(18); // 保留 18 位小数
        row.lottery_status = 'Finished';
        
        console.log(`  ✓ 余额: ${balance} ETH`);
        successCount++;
        
        // 延迟 200ms，避免 API 限流
        await delay(200);
        
      } catch (error) {
        console.error(`  ✗ 查询失败: ${error.message}`);
        failCount++;
      }
    }
    
    // 写回 CSV 文件
    const newCSVContent = generateCSV(headers, rows);
    fs.writeFileSync(CSV_FILE_PATH, newCSVContent, 'utf-8');
    
    console.log('\n=================================');
    console.log('查询完成！');
    console.log(`成功: ${successCount} 个`);
    console.log(`失败: ${failCount} 个`);
    console.log(`CSV 文件已更新: ${CSV_FILE_PATH}`);
    console.log('=================================\n');
    
  } catch (error) {
    console.error('错误:', error.message);
    process.exit(1);
  }
}

// 运行
main();
