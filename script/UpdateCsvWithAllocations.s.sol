// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RedPacketVRF.sol";

/**
 * 更新 CSV 脚本：查询链上分配金额并更新 participants.csv
 * 
 * 运行命令（需要 --ffi 允许文件访问）：
 *   set -a; source .env; set +a
 *   forge script script/UpdateCsvWithAllocations.s.sol --rpc-url $RPC_URL --ffi -vvv
 * 
 * 依赖环境变量：
 *   RPC_URL
 *   RED_PACKET
 *   CSV_PATH (可选，默认 data/participants.csv)
 */
contract UpdateCsvWithAllocations is Script {
    function run() external {
        address redPacketAddr = vm.envAddress("RED_PACKET");
        string memory csvPath = string.concat(vm.projectRoot(), "/data/participants.csv");
        
        RedPacketVRF red = RedPacketVRF(payable(redPacketAddr));
        
        // 获取所有参与者的分配
        (address[] memory addrs, uint256[] memory amounts) = red.getParticipantAmountMapping();
        
        console2.log("Reading CSV from:", csvPath);
        string memory content = vm.readFile(csvPath);
        
        // 按行分割
        string[] memory lines = vm.split(content, "\n");
        require(lines.length > 1, "CSV is empty or has only header");
        
        // 解析表头，找到列索引
        string[] memory headers = vm.split(lines[0], ",");
        uint256 addrIdx = type(uint256).max;
        uint256 balanceIdx = type(uint256).max;
        uint256 statusIdx = type(uint256).max;
        
        for (uint256 i = 0; i < headers.length; i++) {
            bytes32 h = keccak256(bytes(_trim(headers[i])));
            if (h == keccak256("wallet_address")) {
                addrIdx = i;
            } else if (h == keccak256("lottery_balance")) {
                balanceIdx = i;
            } else if (h == keccak256("lottery_status")) {
                statusIdx = i;
            }
        }
        
        require(addrIdx != type(uint256).max, "wallet_address column not found");
        require(balanceIdx != type(uint256).max, "lottery_balance column not found");
        require(statusIdx != type(uint256).max, "lottery_status column not found");
        
        // 构建新 CSV 内容
        string memory newContent = string.concat(lines[0], "\n");
        uint256 updatedCount = 0;
        
        for (uint256 i = 1; i < lines.length; i++) {
            string memory line = lines[i];
            if (bytes(line).length == 0) continue;
            
            string[] memory cols = vm.split(line, ",");
            if (cols.length <= addrIdx || cols.length <= balanceIdx || cols.length <= statusIdx) {
                // 保持原行不变
                newContent = string.concat(newContent, line, "\n");
                continue;
            }
            
            // 解析地址
            address participant = _safeParseAddress(_trim(cols[addrIdx]));
            if (participant == address(0)) {
                newContent = string.concat(newContent, line, "\n");
                continue;
            }
            
            // 查询链上金额
            uint256 amount = 0;
            for (uint256 k = 0; k < addrs.length; k++) {
                if (addrs[k] == participant) {
                    amount = amounts[k];
                    break;
                }
            }
            
            // 更新字段
            cols[balanceIdx] = vm.toString(amount); 
            cols[statusIdx] = amount > 0 ? "Finished" : cols[statusIdx];
            
            // 重新拼接行
            string memory newLine = cols[0];
            for (uint256 j = 1; j < cols.length; j++) {
                newLine = string.concat(newLine, ",", cols[j]);
            }
            newContent = string.concat(newContent, newLine, "\n");
            
            updatedCount++;
            console2.log("Updated:", participant, "balance:", amount);
        }
        
        // 写回文件
        vm.writeFile(csvPath, newContent);
        console2.log("\n=== CSV Update Complete ===");
        console2.log("File:", csvPath);
        console2.log("Rows updated:", updatedCount);
        console2.log("Participants on chain:", addrs.length);
    }
    
    /// @dev 去除字符串首尾空格
    function _trim(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 start = 0;
        uint256 end = b.length;
        
        while (start < end && (b[start] == 0x20 || b[start] == 0x09)) {
            start++;
        }
        while (end > start && (b[end - 1] == 0x20 || b[end - 1] == 0x09 || b[end - 1] == 0x0d)) {
            end--;
        }
        
        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            result[i] = b[start + i];
        }
        return string(result);
    }
    
    /// @dev 安全解析地址
    function _safeParseAddress(string memory s) internal pure returns (address) {
        bytes memory b = bytes(s);
        if (b.length != 42 || b[0] != 0x30 || b[1] != 0x78) {
            return address(0);
        }
        
        uint160 addr = 0;
        for (uint256 i = 2; i < 42; i++) {
            uint8 digit = uint8(b[i]);
            uint8 val;
            if (digit >= 48 && digit <= 57) {
                val = digit - 48;
            } else if (digit >= 65 && digit <= 70) {
                val = digit - 55;
            } else if (digit >= 97 && digit <= 102) {
                val = digit - 87;
            } else {
                return address(0);
            }
            addr = addr * 16 + val;
        }
        return address(addr);
    }
}
