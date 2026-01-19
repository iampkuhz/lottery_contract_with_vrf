// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

/*
 * 测试数据生成脚本：两列 CSV -> participants.csv
 *
 * 用途：
 *   仅用于测试场景，将 “工号,地址” 的简化 CSV 转成完整 participants.csv。
 *
 * 默认路径：
 *   输入：data/id_address.test.csv
 *   输出：data/participants.csv
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/TestGenerateParticipantsCsv.s.sol
 *
 * 可选环境变量：
 *   CSV_SIMPLE_PATH  # 简化 CSV 输入路径
 *   CSV_OUTPUT_PATH  # 输出 participants.csv 路径
 */
contract TestGenerateParticipantsCsv is Script {
    function run() external {
        string memory inPath = vm.envOr("CSV_SIMPLE_PATH", string("data/id_address.test.csv"));
        string memory outPath = vm.envOr("CSV_OUTPUT_PATH", string("data/participants.csv"));

        string memory csv = vm.readFile(inPath);
        bytes memory data = bytes(csv);

        string memory header = "id,user_id,user_name,user_avatar,wallet_address,wallet_type,created_at,updated_at,lottery_entered,lottery_status,lottery_balance,message\n";
        string memory out = header;

        bytes1 delimiter = _detectDelimiter(data);

        uint256 lineStart = 0;
        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == "\n") {
                if (i > lineStart) {
                    string memory line = _sliceString(data, lineStart, i - lineStart);
                    line = _trimCR(line);
                    if (bytes(line).length > 0) {
                        string memory col0 = _csvColumn(line, 0, delimiter);
                        string memory col1 = _csvColumn(line, 1, delimiter);
                        if (_isDigits(col0)) {
                            // 构造测试行
                            string memory row = string(
                                abi.encodePacked(
                                    "test-",
                                    col0,
                                    ",",
                                    col0,
                                    ",,,",
                                    col1,
                                    ",test,,," ,
                                    "true,ADDRESS_REGISTED,0,\n"
                                )
                            );
                            out = string(abi.encodePacked(out, row));
                        }
                    }
                }
                lineStart = i + 1;
            }
        }

        vm.writeFile(outPath, out);
    }

    function _csvColumn(string memory line, uint256 index, bytes1 delimiter) internal pure returns (string memory) {
        bytes memory b = bytes(line);
        uint256 start = 0;
        uint256 col = 0;
        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == delimiter) {
                if (col == index) {
                    return _sliceString(b, start, i - start);
                }
                col++;
                start = i + 1;
            }
        }
        return "";
    }

    function _sliceString(bytes memory data, uint256 start, uint256 len) internal pure returns (string memory) {
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = data[start + i];
        }
        return string(out);
    }

    function _trimCR(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length > 0 && b[b.length - 1] == "\r") {
            bytes memory out = new bytes(b.length - 1);
            for (uint256 i = 0; i < b.length - 1; i++) {
                out[i] = b[i];
            }
            return string(out);
        }
        return s;
    }

    function _detectDelimiter(bytes memory data) internal pure returns (bytes1) {
        uint256 lineEnd = data.length;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == "\n") {
                lineEnd = i;
                break;
            }
        }
        for (uint256 i = 0; i < lineEnd; i++) {
            if (data[i] == "\t") {
                return "\t";
            }
        }
        return ",";
    }

    function _isDigits(string memory s) internal pure returns (bool) {
        bytes memory b = bytes(s);
        if (b.length == 0) {
            return false;
        }
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] < "0" || b[i] > "9") {
                return false;
            }
        }
        return true;
    }
}
