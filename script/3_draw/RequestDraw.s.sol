// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RedPacketVRF.sol";
import "../src/interfaces/IVRFV2PlusWrapper.sol";

/*
 * 发起抽奖请求脚本
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/3_draw/RequestDraw.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --ffi
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY
 *   RED_PACKET
 *   MAX_VRF_FEE_WEI（可选，上限保护）
 */
contract RequestDraw is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address redPacketAddr = vm.envAddress("RED_PACKET");
        uint256 maxFeeWei = vm.envOr("MAX_VRF_FEE_WEI", type(uint256).max);

        RedPacketVRF redPacket = RedPacketVRF(payable(redPacketAddr));
        address wrapper = redPacket.vrfWrapper();
        require(wrapper.code.length > 0, "WrapperNoCode");

        string[] memory cmd = new string[](4);
        cmd[0] = "cast";
        cmd[1] = "gas-price";
        cmd[2] = "--rpc-url";
        cmd[3] = vm.envString("RPC_URL");
        bytes memory out = vm.ffi(cmd);
        uint256 gasPriceWei = vm.parseUint(string(out));
        vm.txGasPrice(gasPriceWei);

        uint32 callbackGasLimit = redPacket.callbackGasLimit();
        uint32 numWords = redPacket.numWords();
        uint256 priceWei = IVRFV2PlusWrapper(wrapper).calculateRequestPriceNative(callbackGasLimit, numWords);
        require(priceWei <= maxFeeWei, "VrfFeeTooHigh");

        vm.startBroadcast(pk);
        redPacket.requestDraw();
        vm.stopBroadcast();

        console2.log("tx.gasprice", tx.gasprice);
        console2.log("vrf.wrapper", wrapper);
        console2.log("vrf.priceNative.wei", priceWei);
        console2.log("vrf.maxFee.wei", maxFeeWei);
    }
}
