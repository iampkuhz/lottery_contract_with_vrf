#!/usr/bin/env node
/**
 * 分配脚本：触发红包分配（随机数就绪后执行）(Node.js 版本)
 *
 * 安装依赖：
 *   npm install ethers dotenv
 *
 * 运行命令：
 *   node script/3_draw/distribute.js
 *
 * 依赖环境变量：
 *   RPC_URL - RPC 节点地址
 *   PRIVATE_KEY - 管理员私钥（带 0x 前缀）
 *   RED_PACKET - 红包合约地址
 */

require('dotenv').config();
const { ethers } = require('ethers');

// RedPacketVRF 合约 ABI（仅包含需要的方法）
const RED_PACKET_ABI = [
  'function randomReady() view returns (bool)',
  'function distribute() external',
  'event DrawCompleted(uint256 indexed requestId, uint256 totalAmount, uint256 participantCount)'
];

async function main () {
  // 读取环境变量
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  const redPacketAddress = process.env.RED_PACKET;

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

  // 创建 provider 和 wallet
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);

  console.log('分配信息:');
  console.log('  管理员地址:', wallet.address);
  console.log('  红包合约:', redPacketAddress);

  // 连接红包合约
  const redPacket = new ethers.Contract(redPacketAddress, RED_PACKET_ABI, wallet);

  // 检查随机数是否就绪
  console.log('\n检查随机数状态...');
  const randomReady = await redPacket.randomReady();

  if (!randomReady) {
    throw new Error('随机数尚未就绪，请等待 VRF 响应后再执行分配');
  }

  console.log('✓ 随机数已就绪，可以进行分配');

  // 发送分配交易（ethers.js 自动评估 gas）
  console.log('\n发送分配交易...');
  const tx = await redPacket.distribute();

  console.log('交易哈希:', tx.hash);

  // 等待确认
  console.log('等待交易确认...');
  const receipt = await tx.wait();
  console.log('交易已确认，区块号:', receipt.blockNumber);
  console.log('Gas 使用:', receipt.gasUsed.toString());

  // 解析事件
  const drawCompletedEvent = receipt.logs.find(log => {
    try {
      const parsed = redPacket.interface.parseLog({
        topics: log.topics,
        data: log.data
      });
      return parsed && parsed.name === 'DrawCompleted';
    } catch {
      return false;
    }
  });

  if (drawCompletedEvent) {
    const parsed = redPacket.interface.parseLog({
      topics: drawCompletedEvent.topics,
      data: drawCompletedEvent.data
    });
    console.log('\n✅ 红包分配成功！');
    console.log('  Request ID:', parsed.args.requestId.toString());
    console.log('  总金额:', ethers.formatEther(parsed.args.totalAmount), 'ETH');
    console.log('  参与者数:', parsed.args.participantCount.toString());
  } else {
    console.log('\n✅ 交易已确认！');
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ 错误:', error.message);
    process.exit(1);
  });
