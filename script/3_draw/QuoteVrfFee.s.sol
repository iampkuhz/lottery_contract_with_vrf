// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../src/interfaces/IVRFV2PlusWrapper.sol";

/*
 * 查询 VRF Direct Funding 费用（原生币）
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/3_draw/QuoteVrfFee.s.sol --fork-url $RPC_URL --ffi
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
        string[] memory cmd = new string[](5);
        cmd[0] = "cast";
        cmd[1] = "rpc";
        cmd[2] = "eth_gasPrice";
        cmd[3] = "--rpc-url";
        cmd[4] = vm.envString("RPC_URL");
        bytes memory out = vm.ffi(cmd);
        string memory raw = string(out);
        string memory trimmed = _stripQuotes(raw);
        uint256 gasPriceWei = vm.parseUint(trimmed);
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

    function _stripQuotes(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length >= 2 && b[0] == "\"" && b[b.length - 1] == "\"") {
            bytes memory out = new bytes(b.length - 2);
            for (uint256 i = 0; i < b.length - 2; i++) {
                out[i] = b[i + 1];
            }
            return string(out);
        }
        return s;
    }
}
