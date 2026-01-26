#!/usr/bin/env node
/**
 * 紧急回调随机数脚本 (Node.js 版本)
 *
 * 用途：在 Chainlink VRF 回调失败或延迟时，管理员可手动填充随机数并继续分配流程
 *
 * 安装依赖：
 *   npm install ethers dotenv
 *
 * 运行命令：
 *   node script/3_draw/emergencyFulfill.js
 *
 * 依赖环境变量：
 *   RPC_URL - RPC 节点地址
 *   PRIVATE_KEY - 管理员私钥（带 0x 前缀）
 *   RED_PACKET - 红包合约地址
 *   RANDOM_WORD - 随机数（可选，默认使用当前时间戳）
 */

require('dotenv').config();
const { ethers } = require('ethers');

// RedPacketVRF 合约 ABI（仅包含需要的方法）
const RED_PACKET_ABI = [
  'function emergencyFulfillRandomWords(uint256[] memory randomWords) external',
  'function drawInProgress() view returns (bool)',
  'function randomReady() view returns (bool)',
  'function lastRandomWord() view returns (uint256)'
];

async function main () {
  // 读取环境变量
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  const redPacketAddress = process.env.RED_PACKET;
  const randomWord = process.env.RANDOM_WORD
    ? BigInt(process.env.RANDOM_WORD)
    : BigInt(Math.floor(Date.now() / 1000)); // 默认使用当前时间戳

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

  try {
    // 初始化提供者和签名者
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const signer = new ethers.Wallet(privateKey, provider);
    console.log('✓ 连接到 RPC:', rpcUrl);
    console.log('✓ 管理员地址:', signer.address);

    // 初始化红包合约
    const redPacket = new ethers.Contract(
      redPacketAddress,
      RED_PACKET_ABI,
      signer
    );
    console.log('✓ 合约地址:', redPacketAddress);

    // 检查合约状态
    const drawInProgress = await redPacket.drawInProgress();
    console.log('✓ 抽奖进行中:', drawInProgress);
    if (!drawInProgress) {
      throw new Error('未进行中的抽奖，无法执行紧急回调');
    }

    console.log('✓ 随机数值:', randomWord.toString());

    // 执行紧急回调
    console.log('\n⏳ 发送紧急回调交易...');
    const tx = await redPacket.emergencyFulfillRandomWords([randomWord]);
    console.log('✓ 交易哈希:', tx.hash);

    // 等待交易确认
    console.log('⏳ 等待交易确认...');
    const receipt = await tx.wait();
    console.log('✓ 交易已确认');
    console.log('✓ 区块号:', receipt.blockNumber);
    console.log('✓ Gas 使用:', receipt.gasUsed.toString());

    // 验证状态更新
    const newRandomWord = await redPacket.lastRandomWord();
    const randomReady = await redPacket.randomReady();
    console.log('\n✓ 新的随机数:', newRandomWord.toString());
    console.log('✓ 随机数就绪:', randomReady);

    console.log('\n✅ 紧急回调执行成功！');
  } catch (error) {
    console.error('❌ 错误:', error.message);
    process.exit(1);
  }
}

main();
