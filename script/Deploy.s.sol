// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/RedPacketVRF.sol";

/*
 * 部署脚本：读取环境变量并部署合约
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   ## 加上  --skip-simulation 跳过本地 simulation，强烈【不推荐】
 *   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY
 *   VRF_COORDINATOR
 *   KEY_HASH
 *   SUB_ID
 */
contract Deploy is Script {
    function run() external returns (RedPacketVRF deployed) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address coordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 keyHash = vm.envBytes32("KEY_HASH");
        uint256 subId = vm.envUint("SUB_ID");

        vm.startBroadcast(pk);
        deployed = new RedPacketVRF(coordinator, keyHash, subId);
        vm.stopBroadcast();
    }
}
