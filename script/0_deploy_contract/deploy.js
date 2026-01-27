#!/usr/bin/env node
/**
 * 部署脚本：部署 RedPacketVRF 合约 (Node.js 版本)
 *
 * 安装依赖：
 *   npm install ethers dotenv
 *
 * 运行命令：
 *   node script/0_deploy_contract/deploy.js
 *
 * 依赖环境变量：
 *   RPC_URL - RPC 节点地址
 *   PRIVATE_KEY - 部署者私钥（带 0x 前缀）
 *   VRF_WRAPPER - VRF Wrapper 合约地址
 *   ETHERSCAN_API_KEY - Etherscan API Key（可选，用于验证合约）
 */

require('dotenv').config();
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

// RedPacketVRF 合约字节码和 ABI
// 需要从编译结果中获取，这里使用占位符
const RED_PACKET_ABI = [
  'constructor(address _vrfWrapper)',
  'function vrfWrapper() view returns (address)',
  'function owner() view returns (address)'
];

async function main () {
  // 读取环境变量
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  const vrfWrapper = process.env.VRF_WRAPPER;
  const etherscanKey = process.env.ETHERSCAN_API_KEY;

  // 验证必需的环境变量
  if (!rpcUrl) {
    throw new Error('缺少环境变量: RPC_URL');
  }
  if (!privateKey) {
    throw new Error('缺少环境变量: PRIVATE_KEY');
  }
  if (!vrfWrapper) {
    throw new Error('缺少环境变量: VRF_WRAPPER');
  }

  // 读取编译后的合约
  const artifactPath = path.join(__dirname, '../../out/RedPacketVRF.sol/RedPacketVRF.json');

  if (!fs.existsSync(artifactPath)) {
    throw new Error(`未找到合约编译文件: ${artifactPath}\n请先运行: forge build`);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf-8'));
  const bytecode = artifact.bytecode.object;
  const abi = artifact.abi;

  if (!bytecode || bytecode === '0x') {
    throw new Error('合约字节码为空，请重新编译');
  }

  // 创建 provider 和 wallet
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);

  console.log('部署信息:');
  console.log('  部署者地址:', wallet.address);
  console.log('  VRF Wrapper:', vrfWrapper);
  console.log('  字节码大小:', (bytecode.length - 2) / 2, '字节');

  // 验证 VRF Wrapper 地址
  const wrapperCode = await provider.getCode(vrfWrapper);
  if (wrapperCode === '0x') {
    throw new Error('VRF Wrapper 地址无合约代码，请检查地址正确性');
  }

  // 获取当前 nonce
  const nonce = await provider.getTransactionCount(wallet.address);
  console.log('  当前 Nonce:', nonce);

  // 计算部署后的合约地址
  const deploymentAddress = ethers.getCreateAddress({
    from: wallet.address,
    nonce: nonce
  });
  console.log('\n预期部署地址:', deploymentAddress);

  // 获取 gas 价格
  const feeData = await provider.getFeeData();
  const gasPrice = feeData.gasPrice;
  console.log('当前 Gas Price:', ethers.formatUnits(gasPrice, 'gwei'), 'gwei');

  // 创建合约工厂
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);

  // 部署合约
  console.log('\n开始部署合约...');
  const contract = await factory.deploy(vrfWrapper, {
    gasPrice: gasPrice
  });

  console.log('部署交易哈希:', contract.deploymentTransaction().hash);

  // 等待部署确认
  console.log('等待部署确认...');
  const receipt = await contract.deploymentTransaction().wait();

  console.log('\n✅ 部署成功！');
  console.log('  实际部署地址:', await contract.getAddress());
  console.log('  区块号:', receipt.blockNumber);
  console.log('  Gas 使用:', receipt.gasUsed.toString());

  // 验证部署
  console.log('\n验证部署...');
  const deployedWrapper = await contract.vrfWrapper();
  const deployedOwner = await contract.owner();

  console.log('  VRF Wrapper (验证):', deployedWrapper);
  console.log('  Owner (验证):', deployedOwner);

  if (deployedWrapper.toLowerCase() !== vrfWrapper.toLowerCase()) {
    throw new Error('VRF Wrapper 地址不匹配');
  }
  if (deployedOwner.toLowerCase() !== wallet.address.toLowerCase()) {
    throw new Error('Owner 地址不匹配');
  }

  // 保存部署信息
  const deployInfo = {
    address: await contract.getAddress(),
    vrfWrapper: deployedWrapper,
    owner: deployedOwner,
    blockNumber: receipt.blockNumber,
    transactionHash: receipt.hash,
    timestamp: new Date().toISOString()
  };

  const deployInfoPath = path.join(__dirname, '../../.deploy-info.json');
  fs.writeFileSync(deployInfoPath, JSON.stringify(deployInfo, null, 2));
  console.log('\n部署信息已保存到:', deployInfoPath);

  console.log('\n💡 提示：');
  if (etherscanKey) {
    console.log('  建议在 Etherscan 上验证合约:');
    console.log('  https://sepolia.etherscan.io/address/' + await contract.getAddress());
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ 错误:', error.message);
    process.exit(1);
  });
