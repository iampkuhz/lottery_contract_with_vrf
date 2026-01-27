const fs = require('fs');

// 生成 UUID 的简单方法
function generateUUID () {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
    const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// 生成随机钱包地址
function generateWalletAddress () {
  const chars = '0123456789abcdef';
  let address = '0x';
  for (let i = 0; i < 40; i++) {
    address += chars[Math.floor(Math.random() * 16)];
  }
  return address;
}

// CSV 标题
const header = 'id,user_id,user_name,user_avatar,wallet_address,wallet_type,created_at,updated_at,lottery_entered,lottery_status,lottery_balance,message,user_department';

// 生成数据行
let csv = header + '\n';
for (let i = 1; i <= 300; i++) {
  const id = generateUUID();
  const userId = 100000 + i;
  const userName = '测试用户' + i;
  const userAvatar = '//example.com/avatar/' + userId + '.jpg';
  const walletAddress = generateWalletAddress();
  const walletType = 'generated';
  const now = new Date().toISOString();
  const lotteryEntered = 'false';
  const lotteryStatus = 'ADDRESS_LOADED';
  const lotteryBalance = '0';
  const message = '';
  const userDepartment = '测试部门' + (i % 5 + 1);

  csv += [id, userId, userName, userAvatar, walletAddress, walletType, now, now, lotteryEntered, lotteryStatus, lotteryBalance, message, userDepartment].join(',') + '\n';
}

fs.writeFileSync('data/participants.csv', csv);
console.log('✅ 已生成 300 条测试数据');
