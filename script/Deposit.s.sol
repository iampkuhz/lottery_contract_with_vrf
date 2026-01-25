// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

/*
 * 充值脚本：向红包合约充值 ETH
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/Deposit.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY
 *   RED_PACKET
 *   DEPOSIT_AMOUNT (可选，默认 0.001 ETH)
 */
contract Deposit is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address payable redPacketAddr = payable(vm.envAddress("RED_PACKET"));
        // 默认 0.001 ETH，可通过环境变量覆盖
        uint256 amount = vm.envOr("DEPOSIT_AMOUNT", uint256(0.1 ether));

        vm.startBroadcast(pk);
        (bool success, ) = redPacketAddr.call{value: amount}("");
        require(success, "Deposit failed");
        vm.stopBroadcast();
    }
}
