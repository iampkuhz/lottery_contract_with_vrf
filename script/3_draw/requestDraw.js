#!/usr/bin/env node
/**
 * 发起抽奖请求脚本 (Node.js 版本)
 *
 * 安装依赖：
 *   npm install ethers dotenv
 *
 * 运行命令：
 *   node script/3_draw/requestDraw.js
 *
 * 依赖环境变量：
 *   RPC_URL - RPC 节点地址
 *   PRIVATE_KEY - 管理员私钥（带 0x 前缀）
 *   RED_PACKET - 红包合约地址
 *   MAX_VRF_FEE_WEI - VRF 费用上限（可选，默认无限制）
 */

require('dotenv').config();
const { ethers } = require('ethers');

// RedPacketVRF 合约 ABI（仅包含需要的方法）
const RED_PACKET_ABI = [
  'function vrfWrapper() view returns (address)',
  'function callbackGasLimit() view returns (uint32)',
  'function numWords() view returns (uint32)',
  'function requestDraw() external',
  'function drawInProgress() view returns (bool)',
  'event DrawRequested(uint256 indexed requestId)'
];

// IVRFV2PlusWrapper 接口 ABI
const VRF_WRAPPER_ABI = [
  'function calculateRequestPriceNative(uint32 callbackGasLimit, uint32 numWords) view returns (uint256)'
];

async function main () {
  // 读取环境变量
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  const redPacketAddress = process.env.RED_PACKET;
  const maxFeeWei = process.env.MAX_VRF_FEE_WEI
    ? BigInt(process.env.MAX_VRF_FEE_WEI)
    : BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');

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

  console.log('管理员地址:', wallet.address);
  console.log('红包合约地址:', redPacketAddress);

  // 连接红包合约
  const redPacket = new ethers.Contract(redPacketAddress, RED_PACKET_ABI, wallet);

  // 检查是否已经在抽奖中
  const inProgress = await redPacket.drawInProgress();
  if (inProgress) {
    throw new Error('抽奖已在进行中，请等待完成');
  }

  // 获取 VRF Wrapper 地址和参数
  const wrapperAddress = await redPacket.vrfWrapper();
  const callbackGasLimit = await redPacket.callbackGasLimit();
  const numWords = await redPacket.numWords();

  console.log('\nVRF 配置:');
  console.log('  Wrapper 地址:', wrapperAddress);
  console.log('  回调 Gas 限制:', callbackGasLimit.toString());
  console.log('  随机数数量:', numWords.toString());

  // 验证 Wrapper 地址
  const wrapperCode = await provider.getCode(wrapperAddress);
  if (wrapperCode === '0x') {
    throw new Error('VRF Wrapper 地址无合约代码');
  }

  // 连接 VRF Wrapper 合约并查询费用
  const vrfWrapper = new ethers.Contract(wrapperAddress, VRF_WRAPPER_ABI, provider);
  const priceWei = await vrfWrapper.calculateRequestPriceNative(callbackGasLimit, numWords);

  console.log('\nVRF 费用:');
  console.log('  预估费用:', ethers.formatEther(priceWei), 'ETH');
  console.log('  费用上限:', maxFeeWei === BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
    ? '无限制'
    : ethers.formatEther(maxFeeWei) + ' ETH');

  // 检查费用是否超过上限
  if (priceWei > maxFeeWei) {
    throw new Error(`VRF 费用 (${ethers.formatEther(priceWei)} ETH) 超过上限 (${ethers.formatEther(maxFeeWei)} ETH)`);
  }

  // 获取当前 gas price
  const feeData = await provider.getFeeData();
  const gasPrice = feeData.gasPrice;
  console.log('\n当前 Gas Price:', ethers.formatUnits(gasPrice, 'gwei'), 'gwei');

  // 发送交易
  console.log('\n发送抽奖请求...');
  const tx = await redPacket.requestDraw({
    gasPrice: gasPrice
  });

  console.log('交易哈希:', tx.hash);

  // 等待确认
  console.log('等待交易确认...');
  const receipt = await tx.wait();
  console.log('交易已确认，区块号:', receipt.blockNumber);
  console.log('Gas 使用:', receipt.gasUsed.toString());

  // 解析事件
  const drawRequestedEvent = receipt.logs.find(log => {
    try {
      const parsed = redPacket.interface.parseLog({
        topics: log.topics,
        data: log.data
      });
      return parsed && parsed.name === 'DrawRequested';
    } catch {
      return false;
    }
  });

  if (drawRequestedEvent) {
    const parsed = redPacket.interface.parseLog({
      topics: drawRequestedEvent.topics,
      data: drawRequestedEvent.data
    });
    console.log('\n✅ 抽奖请求已发起！');
    console.log('Request ID:', parsed.args.requestId.toString());
  } else {
    console.log('\n✅ 交易已确认！');
  }

  console.log('\n💡 提示: VRF 随机数生成需要几分钟时间，请耐心等待 Chainlink 节点响应');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ 错误:', error.message);
    process.exit(1);
  });
