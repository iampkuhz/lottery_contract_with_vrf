#!/usr/bin/env node
/**
 * 录入脚本：按批次录入参与者 (Node.js 版本)
 *
 * 安装依赖：
 *   npm install ethers dotenv csv-parse
 *
 * 运行命令：
 *   node script/2_register_addresses/registerBatch.js
 *
 * 依赖环境变量：
 *   RPC_URL - RPC 节点地址
 *   PRIVATE_KEY - 管理员私钥（带 0x 前缀）
 *   RED_PACKET - 红包合约地址
 *   BATCH_SIZE - 每批录入数量（可选，默认 100）
 *   CSV_PATH - CSV 文件路径（可选，默认 data/participants.csv）
 *   FORCE_SUBMIT - 遇到错误是否跳过（可选，1=跳过 0=中止，默认 0）
 *   EOA_CHECK - 是否校验地址为 EOA（可选，1=校验 0=跳过，默认 1）
 *
 * CSV 格式：
 *   id,user_id,user_name,user_avatar,wallet_address,wallet_type,created_at,updated_at,lottery_entered,lottery_status,lottery_balance,message
 *
 * 映射规则：
 *   employeeId = user_id (第2列)
 *   participant = wallet_address (第5列)
 */

require('dotenv').config();
const { ethers } = require('ethers');
const fs = require('fs');
const { parse } = require('csv-parse/sync');

// RedPacketVRF 合约 ABI（仅包含需要的方法）
const RED_PACKET_ABI = [
  'function setParticipantsBatch(uint256[] calldata employeeIds, address[] calldata participants) external',
  'function drawInProgress() view returns (bool)',
  'event ParticipantSet(uint256 indexed employeeId, address indexed participant)'
];

async function main () {
  // 读取环境变量
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  const redPacketAddress = process.env.RED_PACKET;
  const batchSize = parseInt(process.env.BATCH_SIZE || '100', 10);
  const csvPath = process.env.CSV_PATH || 'data/participants.csv';
  const forceSubmit = process.env.FORCE_SUBMIT === '1';
  const enableEoaCheck = process.env.EOA_CHECK !== '0';

  // 验证必需的环境变量
  if (!rpcUrl) {
    throw new Error('缺少环境变量: RPC_URL');
  }
  if (!privateKey) {
    throw new Error('缺少环境变量: PRIVATE_KEY');
  }
  if (!redPacketAddress) {
    throw new Error('缺少环境变量: RED_PACKET');
  }

  console.log('配置信息:');
  console.log('  CSV 路径:', csvPath);
  console.log('  红包合约:', redPacketAddress);
  console.log('  批次大小:', batchSize);
  console.log('  强制提交:', forceSubmit ? '是' : '否');
  console.log('  校验 EOA:', enableEoaCheck ? '是' : '否');

  // 创建 provider 和 wallet
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);

  console.log('  管理员地址:', wallet.address);

  // 连接红包合约
  const redPacket = new ethers.Contract(redPacketAddress, RED_PACKET_ABI, wallet);

  // 检查是否在抽奖中
  const inProgress = await redPacket.drawInProgress();
  if (inProgress) {
    throw new Error('抽奖进行中，无法录入参与者');
  }

  // 读取并解析 CSV 文件
  console.log('\n读取 CSV 文件...');
  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const records = parse(csvContent, {
    columns: true,
    skip_empty_lines: true,
    trim: true
  });

  console.log('CSV 总行数:', records.length);

  // 解析数据
  const participants = [];
  let skipped = 0;

  for (let i = 0; i < records.length; i++) {
    const record = records[i];
    const userId = record.user_id?.trim();
    const walletAddress = record.wallet_address?.trim();

    // 验证数据
    if (!userId || !walletAddress) {
      if (forceSubmit) {
        skipped++;
        console.log(`  跳过第 ${i + 2} 行: user_id 或 wallet_address 为空`);
        continue;
      } else {
        throw new Error(`第 ${i + 2} 行数据无效: user_id 或 wallet_address 为空`);
      }
    }

    // 验证 userId 是否为数字
    const employeeId = parseInt(userId, 10);
    if (isNaN(employeeId) || employeeId <= 0) {
      if (forceSubmit) {
        skipped++;
        console.log(`  跳过第 ${i + 2} 行: user_id 不是有效数字`);
        continue;
      } else {
        throw new Error(`第 ${i + 2} 行数据无效: user_id 不是有效数字`);
      }
    }

    // 验证地址
    if (!ethers.isAddress(walletAddress)) {
      if (forceSubmit) {
        skipped++;
        console.log(`  跳过第 ${i + 2} 行: wallet_address 不是有效地址`);
        continue;
      } else {
        throw new Error(`第 ${i + 2} 行数据无效: wallet_address 不是有效地址`);
      }
    }
    // 可选：验证不是合约地址（EOA 检查）
    if (enableEoaCheck) {
      const code = await provider.getCode(walletAddress);
      if (code !== '0x') {
        if (forceSubmit) {
          skipped++;
          console.log(`  跳过第 ${i + 2} 行: wallet_address 是合约地址，仅允许 EOA`);
          continue;
        } else {
          throw new Error(`第 ${i + 2} 行数据无效: wallet_address 是合约地址，仅允许 EOA`);
        }
      }
    }

    participants.push({
      employeeId: BigInt(employeeId),
      address: walletAddress
    });
  }

  console.log('\n解析结果:');
  console.log('  有效记录:', participants.length);
  console.log('  跳过记录:', skipped);

  if (participants.length === 0) {
    console.log('\n⚠️  没有有效的参与者数据');
    return;
  }

  // 按批次发送
  const totalBatches = Math.ceil(participants.length / batchSize);
  console.log(`\n开始按批次录入 (共 ${totalBatches} 批)...`);

  let sentBatches = 0;
  for (let i = 0; i < participants.length; i += batchSize) {
    const batch = participants.slice(i, Math.min(i + batchSize, participants.length));
    const employeeIds = batch.map(p => p.employeeId);
    const addresses = batch.map(p => p.address);

    console.log(`\n批次 ${sentBatches + 1}/${totalBatches}:`);
    console.log(`  记录数: ${batch.length}`);
    console.log(`  ID 范围: ${employeeIds[0]} - ${employeeIds[employeeIds.length - 1]}`);

    try {
      // 发送交易
      const tx = await redPacket.setParticipantsBatch(employeeIds, addresses);
      console.log('  交易哈希:', tx.hash);

      // 等待确认
      const receipt = await tx.wait();
      console.log('  已确认，区块:', receipt.blockNumber);
      console.log('  Gas 使用:', receipt.gasUsed.toString());

      sentBatches++;
    } catch (error) {
      console.error(`  ❌ 批次 ${sentBatches + 1} 发送失败:`, error.message);
      if (!forceSubmit) {
        throw error;
      }
    }
  }

  console.log('\n' + '='.repeat(50));
  console.log('录入完成统计:');
  console.log('  CSV 总行数:', records.length);
  console.log('  有效记录:', participants.length);
  console.log('  跳过记录:', skipped);
  console.log('  成功批次:', sentBatches);
  console.log('  总批次数:', totalBatches);
  console.log('='.repeat(50));
  console.log('\n✅ 参与者录入完成！');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ 错误:', error.message);
    process.exit(1);
  });
