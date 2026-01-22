// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/interfaces/IVRFV2PlusWrapper.sol";

/*
 * 查询 VRF Direct Funding 费用（原生币）
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/QuoteVrfFee.s.sol --rpc-url $RPC_URL
 *
 * 依赖环境变量：
 *   RPC_URL
 *   VRF_WRAPPER
 *   （参数固定：callbackGasLimit=70000，numWords=1；gasPrice 自动查询）
 */
contract QuoteVrfFee is Script {
    function run() external {
        address wrapper = vm.envAddress("VRF_WRAPPER");
        uint32 callbackGasLimit = 70_000;
        uint32 numWords = 1;
        string[] memory cmd = new string[](4);
        cmd[0] = "cast";
        cmd[1] = "gas-price";
        cmd[2] = "--rpc-url";
        cmd[3] = vm.envString("RPC_URL");
        bytes memory out = vm.ffi(cmd);
        uint256 gasPriceWei = vm.parseUint(string(out));
        vm.txGasPrice(gasPriceWei);

        IVRFV2PlusWrapper vrf = IVRFV2PlusWrapper(wrapper);

        uint256 priceNative = vrf.calculateRequestPriceNative(callbackGasLimit, numWords);
        console2.log("chainId", block.chainid);
        console2.log("vrf.wrapper", wrapper);
        console2.log("callbackGasLimit", callbackGasLimit);
        console2.log("numWords", numWords);
        console2.log("tx.gasprice", tx.gasprice);
        console2.log("vrf.priceNative.wei", priceNative);
    }
}
