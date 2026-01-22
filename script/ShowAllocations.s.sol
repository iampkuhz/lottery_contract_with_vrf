// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RedPacketVRF.sol";

/*
 * 查看分配结果脚本：读取并打印每位参与者的分配金额
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/ShowAllocations.s.sol --rpc-url $RPC_URL -vvv
 *
 * 依赖环境变量：
 *   RPC_URL
 *   RED_PACKET
 */
contract ShowAllocations is Script {
    function run() external view {
        address redPacketAddr = vm.envAddress("RED_PACKET");
        RedPacketVRF red = RedPacketVRF(payable(redPacketAddr));

        (address[] memory addrs, uint256[] memory amounts) = red.getParticipantAmountMapping();

        uint256 sum = 0;
        uint256 minAmt = type(uint256).max;
        uint256 maxAmt = 0;
        address minAddr = address(0);
        address maxAddr = address(0);

        console2.log("participants", addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            uint256 amt = amounts[i];
            sum += amt;
            if (amt > 0 && amt < minAmt) {
                minAmt = amt;
                minAddr = addrs[i];
            }
            if (amt > maxAmt) {
                maxAmt = amt;
                maxAddr = addrs[i];
            }
            // 明细：索引、地址、金额（wei）
            console2.log("idx", i);
            console2.log("addr", addrs[i]);
            console2.log("amountWei", amt);
        }

        console2.log("sumWei", sum);
        console2.log("maxAddr", maxAddr);
        console2.log("maxWei", maxAmt);
        console2.log("minAddr", minAddr);
        console2.log("minWei", minAmt == type(uint256).max ? 0 : minAmt);
    }
}
