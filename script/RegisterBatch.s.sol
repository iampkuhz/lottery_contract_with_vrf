// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RedPacketVRF.sol";

/*
 * 录入脚本：按批次录入参与者
 *
 * 运行命令：
 *   set -a; source .env; set +a
 *   forge script script/RegisterBatch.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY
 *   RED_PACKET
 *   BATCH_SIZE
 *   CSV_PATH (可选，默认 data/participants.csv)
 *
 * CSV 格式：
 *   id,user_id,user_name,user_avatar,wallet_address,wallet_type,created_at,updated_at,lottery_entered,lottery_status,lottery_balance,message
 *
 * 映射规则：
 *   employeeId = user_id
 *   participant = wallet_address
 */
contract RegisterBatch is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address redPacketAddr = vm.envAddress("RED_PACKET");
        uint256 batchSize = vm.envUint("BATCH_SIZE");
        bool forceSubmit = vm.envOr("FORCE_SUBMIT", uint256(0)) == 1;
        string memory csvPath = vm.envOr("CSV_PATH", string("data/participants.csv"));

        require(redPacketAddr != address(0), "ZeroRedPacket");
        require(batchSize > 0, "ZeroBatchSize");

        RedPacketVRF redPacket = RedPacketVRF(payable(redPacketAddr));
        bytes memory data = bytes(vm.readFile(csvPath));
        require(data.length > 0, "EmptyCsv");

        console2.log("csvPath", csvPath);
        console2.log("redPacket", redPacketAddr);
        console2.log("batchSize", batchSize);
        console2.log("forceSubmit", forceSubmit);

        (uint256 lineNo, uint256 total, uint256 skipped) = _validateCsv(data, forceSubmit);
        (uint256[] memory ids, address[] memory addrs) = _collectCsv(data, total, forceSubmit);

        vm.startBroadcast(pk);

        uint256 sentBatches = _sendBatches(redPacket, ids, addrs, batchSize);
        vm.stopBroadcast();

        console2.log("lines", lineNo);
        console2.log("total", total);
        console2.log("skipped", skipped);
        console2.log("batches", sentBatches);
    }

    function _validateCsv(
        bytes memory data,
        bool forceSubmit
    ) internal view returns (uint256 lineNo, uint256 total, uint256 skipped) {
        uint256 lineStart = 0;

        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == "\n") {
                if (i > lineStart) {
                    string memory line = _sliceString(data, lineStart, i - lineStart);
                    line = _trimCR(line);
                    if (bytes(line).length > 0) {
                        lineNo++;
                        if (lineNo > 1) {
                            (bool ok, uint256 userId, address wallet) = _parseLine(line);
                            if (!ok || userId == 0 || wallet == address(0) || wallet.code.length > 0) {
                                if (forceSubmit) {
                                    skipped++;
                                } else {
                                    require(ok, "InvalidCsvLine");
                                    require(userId > 0, "InvalidUserId");
                                    require(wallet != address(0), "InvalidWallet");
                                    require(wallet.code.length == 0, "ContractNotAllowed");
                                }
                            } else {
                                total++;
                            }
                        }
                    }
                }
                lineStart = i + 1;
            }
        }
    }

    function _collectCsv(
        bytes memory data,
        uint256 total,
        bool forceSubmit
    ) internal pure returns (uint256[] memory ids, address[] memory addrs) {
        ids = new uint256[](total);
        addrs = new address[](total);
        uint256 lineStart = 0;
        uint256 lineNo = 0;
        uint256 idx = 0;

        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == "\n") {
                if (i > lineStart) {
                    string memory line = _sliceString(data, lineStart, i - lineStart);
                    line = _trimCR(line);
                    if (bytes(line).length > 0) {
                        lineNo++;
                        if (lineNo > 1) {
                            (bool ok, uint256 userId, address wallet) = _parseLine(line);
                            if (ok && userId > 0 && wallet != address(0) && wallet.code.length == 0) {
                                ids[idx] = userId;
                                addrs[idx] = wallet;
                                idx++;
                            } else {
                                if (!forceSubmit) {
                                    revert("InvalidCsvLine");
                                }
                            }
                        }
                    }
                }
                lineStart = i + 1;
            }
        }
    }

    function _sendBatches(
        RedPacketVRF redPacket,
        uint256[] memory ids,
        address[] memory addrs,
        uint256 batchSize
    ) internal returns (uint256 sentBatches) {
        uint256 total = ids.length;
        uint256 idx = 0;
        while (idx < total) {
            uint256 remaining = total - idx;
            uint256 size = remaining > batchSize ? batchSize : remaining;
            uint256[] memory chunkIds = new uint256[](size);
            address[] memory chunkAddrs = new address[](size);
            for (uint256 i = 0; i < size; i++) {
                chunkIds[i] = ids[idx + i];
                chunkAddrs[i] = addrs[idx + i];
            }
            redPacket.setParticipantsBatch(chunkIds, chunkAddrs);
            sentBatches++;
            console2.log("batchSent", sentBatches);
            idx += size;
        }
    }

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
}
