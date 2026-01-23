// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

/*
 * 生成 cast 批量录入命令（仅输出，不发送交易）
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/GenerateCastRegisterCommands.s.sol
 *
 * 依赖环境变量：
 *   RED_PACKET
 *   BATCH_SIZE（可选，默认 30）
 *   CSV_PATH (可选，默认 data/participants.csv)
 *   FORCE_SUBMIT（可选，1=跳过不合法地址并继续）
 */
contract GenerateCastRegisterCommands is Script {
    // 单行函数注释：入口函数，读取 CSV 并输出 cast 命令
    function run() external {
        address redPacketAddr = vm.envAddress("RED_PACKET");
        uint256 batchSize = vm.envOr("BATCH_SIZE", uint256(30));
        bool forceSubmit = vm.envOr("FORCE_SUBMIT", uint256(0)) == 1;
        string memory csvPath = vm.envOr("CSV_PATH", string("data/participants.csv"));

        require(redPacketAddr != address(0), "ZeroRedPacket");
        require(batchSize > 0, "ZeroBatchSize");

        bytes memory data = bytes(vm.readFile(csvPath));
        require(data.length > 0, "EmptyCsv");

        console2.log("csvPath", csvPath);
        console2.log("redPacket", redPacketAddr);
        console2.log("batchSize", batchSize);
        console2.log("forceSubmit", forceSubmit);
        console2.log("csvBytes", data.length);

        _emitCastCommands(redPacketAddr, data, batchSize, forceSubmit);
    }

    // 单行函数注释：解析 CSV 并输出命令
    function _emitCastCommands(
        address redPacketAddr,
        bytes memory data,
        uint256 batchSize,
        bool forceSubmit
    ) internal {
        uint256 lineStart = 0;
        uint256 lineNo = 0;
        uint256 chunkIdx = 0;
        uint256[] memory chunkIds = new uint256[](batchSize);
        address[] memory chunkAddrs = new address[](batchSize);

        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == "\n") {
                if (i > lineStart) {
                    string memory line = _sliceString(data, lineStart, i - lineStart);
                    line = _trimCR(line);
                    if (bytes(line).length > 0) {
                        lineNo++;
                        if (lineNo > 1) {
                            (bool ok, uint256 userId, address wallet) = _parseLine(line);
                            if (!ok || userId == 0 || wallet == address(0)) {
                                if (!forceSubmit) {
                                    revert("InvalidCsvLine");
                                }
                            } else {
                                chunkIds[chunkIdx] = userId;
                                chunkAddrs[chunkIdx] = wallet;
                                chunkIdx++;
                                if (chunkIdx == batchSize) {
                                    _printCastCommand(redPacketAddr, chunkIds, chunkAddrs, batchSize);
                                    chunkIdx = 0;
                                }
                            }
                        }
                    }
                }
                lineStart = i + 1;
            }
        }

        if (chunkIdx > 0) {
            uint256[] memory tailIds = new uint256[](chunkIdx);
            address[] memory tailAddrs = new address[](chunkIdx);
            for (uint256 i = 0; i < chunkIdx; i++) {
                tailIds[i] = chunkIds[i];
                tailAddrs[i] = chunkAddrs[i];
            }
            _printCastCommand(redPacketAddr, tailIds, tailAddrs, chunkIdx);
        }
    }

    // 单行函数注释：输出单条 cast send 命令
    function _printCastCommand(
        address redPacketAddr,
        uint256[] memory ids,
        address[] memory addrs,
        uint256 size
    ) internal {
        string memory idsStr = _uintArrayToString(ids, size);
        string memory addrsStr = _addressArrayToString(addrs, size);
        string memory cmd = string(
            abi.encodePacked(
                "cast send ",
                vm.toString(redPacketAddr),
                " \"setParticipantsBatch(uint256[],address[])\" '",
                idsStr,
                "' '",
                addrsStr,
                "' --private-key $PRIVATE_KEY --rpc-url $RPC_URL"
            )
        );
        console2.log(cmd);
    }

    // 单行函数注释：解析单行 CSV
    function _parseLine(string memory line) internal pure returns (bool ok, uint256 userId, address wallet) {
        string memory userIdStr = _csvColumn(line, 1);
        string memory walletStr = _csvColumn(line, 4);
        if (bytes(userIdStr).length == 0 || bytes(walletStr).length == 0) {
            return (false, 0, address(0));
        }
        userId = vm.parseUint(userIdStr);
        wallet = vm.parseAddress(walletStr);
        ok = true;
    }

    // 单行函数注释：获取 CSV 指定列
    function _csvColumn(string memory line, uint256 index) internal pure returns (string memory) {
        bytes memory b = bytes(line);
        uint256 start = 0;
        uint256 col = 0;
        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == ",") {
                if (col == index) {
                    return _sliceString(b, start, i - start);
                }
                col++;
                start = i + 1;
            }
        }
        return "";
    }

    // 单行函数注释：切片字符串
    function _sliceString(bytes memory data, uint256 start, uint256 len) internal pure returns (string memory) {
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = data[start + i];
        }
        return string(out);
    }

    // 单行函数注释：去除行尾回车
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

    // 单行函数注释：拼接 uint256 数组字符串
    function _uintArrayToString(uint256[] memory arr, uint256 size) internal pure returns (string memory) {
        bytes memory out = "[";
        for (uint256 i = 0; i < size; i++) {
            if (i > 0) {
                out = abi.encodePacked(out, ",");
            }
            out = abi.encodePacked(out, vm.toString(arr[i]));
        }
        out = abi.encodePacked(out, "]");
        return string(out);
    }

    // 单行函数注释：拼接 address 数组字符串
    function _addressArrayToString(address[] memory arr, uint256 size) internal pure returns (string memory) {
        bytes memory out = "[";
        for (uint256 i = 0; i < size; i++) {
            if (i > 0) {
                out = abi.encodePacked(out, ",");
            }
            out = abi.encodePacked(out, vm.toString(arr[i]));
        }
        out = abi.encodePacked(out, "]");
        return string(out);
    }
}
