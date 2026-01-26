// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../src/RedPacketVRF.sol";

/*
 * 紧急回调随机数脚本
 *
 * 用途：在 Chainlink VRF 回调失败或延迟时，管理员可手动填充随机数并继续分配流程
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/3_draw/EmergencyFulfill.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY
 *   RED_PACKET
 *   RANDOM_WORD（可选，默认使用当前时间戳）
 */
contract EmergencyFulfill is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address redPacketAddr = vm.envAddress("RED_PACKET");
        uint256 randomWord = vm.envOr("RANDOM_WORD", block.timestamp);

        RedPacketVRF redPacket = RedPacketVRF(payable(redPacketAddr));

        // 验证合约状态
        require(redPacket.drawInProgress(), "NoDrawInProgress");
        console2.log("DrawInProgress: true");
        console2.log("RandomWord:", randomWord);

        // 构造随机数数组
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        // 执行交易
        vm.startBroadcast(pk);
        redPacket.emergencyFulfillRandomWords(randomWords);
        vm.stopBroadcast();

        console2.log("EmergencyFulfill executed successfully");
        console2.log("LastRandomWord:", redPacket.lastRandomWord());
        console2.log("RandomReady:", redPacket.randomReady());
    }
}
