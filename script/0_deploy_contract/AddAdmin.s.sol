// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/RedPacketVRF.sol";

/*
 * 批量添加管理员脚本：为红包合约添加多个管理员
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/0_deploy_contract/AddAdmin.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY     （必须是合约 owner 的私钥）
 *   RED_PACKET      （合约地址）
 *   NEW_ADMINS      （要添加的管理员地址数组，逗号分隔）
 *                   （示例：NEW_ADMINS=0x123...,0x456...,0x789...）
 */
contract AddAdmin is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address redPacketAddr = vm.envAddress("RED_PACKET");
        string memory adminsStr = vm.envString("NEW_ADMINS");

        RedPacketVRF redPacket = RedPacketVRF(payable(redPacketAddr));

        // 解析逗号分隔的地址列表
        address[] memory admins = _parseAddresses(adminsStr);
        require(admins.length > 0, "NoAdminsProvided");

        vm.startBroadcast(pk);
        for (uint i = 0; i < admins.length; i++) {
            if (redPacket.isAdmin(admins[i])) {
                console.log("Already admin, skipped:", admins[i]);
                continue;
            }
            redPacket.addAdmin(admins[i]);
            console.log("Admin added:", admins[i]);
        }
        vm.stopBroadcast();

        console.log("Total admins added:", admins.length);
    }

    function _parseAddresses(string memory input) internal pure returns (address[] memory) {
        bytes memory inputBytes = bytes(input);
        uint count = 1;
        
        // 统计逗号数量以确定地址数量
        for (uint i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == ",") {
                count++;
            }
        }

        address[] memory result = new address[](count);
        uint index = 0;
        uint start = 0;

        for (uint i = 0; i <= inputBytes.length; i++) {
            if (i == inputBytes.length || inputBytes[i] == ",") {
                // 提取当前地址字符串
                bytes memory addrBytes = new bytes(i - start);
                for (uint j = start; j < i; j++) {
                    addrBytes[j - start] = inputBytes[j];
                }
                
                // 移除前后空格
                string memory addrStr = string(_trim(addrBytes));
                result[index] = vm.parseAddress(addrStr);
                index++;
                start = i + 1;
            }
        }

        return result;
    }

    function _trim(bytes memory input) internal pure returns (bytes memory) {
        uint start = 0;
        uint end = input.length;

        // 移除前导空格
        while (start < end && (input[start] == 0x20 || input[start] == 0x09)) {
            start++;
        }

        // 移除尾随空格
        while (end > start && (input[end - 1] == 0x20 || input[end - 1] == 0x09)) {
            end--;
        }

        bytes memory result = new bytes(end - start);
        for (uint i = start; i < end; i++) {
            result[i - start] = input[i];
        }

        return result;
    }
}
