#!/usr/bin/env node
/**
 * 充值脚本：向红包合约充值 ETH (Node.js 版本)
 *
 * 安装依赖：
 *   npm install ethers dotenv
 *
 * 运行命令：
 *   node script/1_deposit_eth/deposit.js
 *
 * 依赖环境变量：
 *   RPC_URL - RPC 节点地址
 *   PRIVATE_KEY - 发送者私钥（带 0x 前缀）
 *   RED_PACKET - 红包合约地址
 *   DEPOSIT_AMOUNT - 充值金额（可选，默认 0.001 ETH）
 */

require('dotenv').config();
const { ethers } = require('ethers');

async function main () {
  // 读取环境变量
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  const redPacketAddress = process.env.RED_PACKET;
  const depositAmount = process.env.DEPOSIT_AMOUNT || '0.001';

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

  console.log('发送者地址:', wallet.address);
  console.log('红包合约地址:', redPacketAddress);
  console.log('充值金额:', depositAmount, 'ETH');

  // 获取当前余额
  const balanceBefore = await provider.getBalance(wallet.address);
  console.log('发送前余额:', ethers.formatEther(balanceBefore), 'ETH');

  // 构建交易
  const tx = {
    to: redPacketAddress,
    value: ethers.parseEther(depositAmount),
  };

  // 发送交易
  console.log('\n发送交易中...');
  const txResponse = await wallet.sendTransaction(tx);
  console.log('交易哈希:', txResponse.hash);

  // 等待确认
  console.log('等待交易确认...');
  const receipt = await txResponse.wait();
  console.log('交易已确认，区块号:', receipt.blockNumber);
  console.log('Gas 使用:', receipt.gasUsed.toString());

  // 获取充值后余额
  const balanceAfter = await provider.getBalance(wallet.address);
  console.log('\n发送后余额:', ethers.formatEther(balanceAfter), 'ETH');

  console.log('\n✅ 充值成功！');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ 错误:', error.message);
    process.exit(1);
  });
