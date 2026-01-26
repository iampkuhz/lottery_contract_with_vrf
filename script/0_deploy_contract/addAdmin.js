#!/usr/bin/env node
/**
 * 添加管理员脚本 (Node.js 版本)
 *
 * 安装依赖：
 *   npm install ethers dotenv
 *
 * 运行命令：
 *   node script/0_deploy_contract/addAdmin.js <新管理员地址>
 *
 * 依赖环境变量：
 *   RPC_URL - RPC 节点地址
 *   PRIVATE_KEY - Owner 私钥（带 0x 前缀）
 *   RED_PACKET - 红包合约地址
 * 
 * 示例：
 *   node script/0_deploy_contract/addAdmin.js 0x1234567890123456789012345678901234567890
 */

require('dotenv').config();
const { ethers } = require('ethers');

// RedPacketVRF 合约 ABI（仅包含需要的方法）
const RED_PACKET_ABI = [
  'function addAdmin(address admin) external',
  'function isAdmin(address admin) view returns (bool)',
  'function owner() view returns (address)',
  'event AdminAdded(address indexed admin)'
];

async function main () {
  // 读取环境变量
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  const redPacketAddress = process.env.RED_PACKET;

  // 读取命令行参数
  const adminAddress = process.argv[2];

  // 验证必需的参数
  if (!rpcUrl) {
    throw new Error('缺少环境变量: RPC_URL');
  }
  if (!privateKey) {
    throw new Error('缺少环境变量: PRIVATE_KEY');
  }
  if (!redPacketAddress) {
    throw new Error('缺少环境变量: RED_PACKET（或通过参数指定: node addAdmin.js <合约地址> <管理员地址>）');
  }
  if (!adminAddress) {
    throw new Error('缺少参数: 新管理员地址\n用法: node addAdmin.js <新管理员地址>');
  }

  // 验证地址格式
  if (!ethers.isAddress(adminAddress)) {
    throw new Error(`无效的管理员地址: ${adminAddress}`);
  }

  // 创建 provider 和 wallet
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);

  console.log('添加管理员信息:');
  console.log('  Owner 地址:', wallet.address);
  console.log('  红包合约:', redPacketAddress);
  console.log('  新管理员:', adminAddress);

  // 连接红包合约
  const redPacket = new ethers.Contract(redPacketAddress, RED_PACKET_ABI, wallet);

  // 验证调用者是 Owner
  const owner = await redPacket.owner();
  if (owner.toLowerCase() !== wallet.address.toLowerCase()) {
    throw new Error('只有 Owner 才能添加管理员');
  }

  // 检查是否已是管理员
  const isAlreadyAdmin = await redPacket.isAdmin(adminAddress);
  if (isAlreadyAdmin) {
    console.log('\n⚠️  该地址已是管理员');
    return;
  }

  // 获取当前 gas price
  const feeData = await provider.getFeeData();
  const gasPrice = feeData.gasPrice;
  console.log('当前 Gas Price:', ethers.formatUnits(gasPrice, 'gwei'), 'gwei');

  // 发送交易
  console.log('\n发送交易...');
  const tx = await redPacket.addAdmin(adminAddress, {
    gasPrice: gasPrice
  });

  console.log('交易哈希:', tx.hash);

  // 等待确认
  console.log('等待交易确认...');
  const receipt = await tx.wait();
  console.log('交易已确认，区块号:', receipt.blockNumber);
  console.log('Gas 使用:', receipt.gasUsed.toString());

  // 验证管理员已添加
  const verifyAdmin = await redPacket.isAdmin(adminAddress);
  if (verifyAdmin) {
    console.log('\n✅ 管理员添加成功！');
  } else {
    console.log('\n❌ 添加失败，请检查交易');
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ 错误:', error.message);
    process.exit(1);
  });
