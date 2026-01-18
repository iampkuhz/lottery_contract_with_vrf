// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/RedPacketVRF.sol";

/*
 * 发起抽奖请求脚本
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/RequestDraw.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY
 *   RED_PACKET
 */
contract RequestDraw is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address redPacketAddr = vm.envAddress("RED_PACKET");

        RedPacketVRF redPacket = RedPacketVRF(payable(redPacketAddr));

        vm.startBroadcast(pk);
        redPacket.requestDraw();
        vm.stopBroadcast();
    }
}
