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
        string memory csvPath = vm.envOr("CSV_PATH", string("data/participants.csv"));

        require(redPacketAddr != address(0), "ZeroRedPacket");
        require(batchSize > 0, "ZeroBatchSize");

        RedPacketVRF redPacket = RedPacketVRF(payable(redPacketAddr));

        string memory csv = vm.readFile(csvPath);
        bytes memory data = bytes(csv);
        require(data.length > 0, "EmptyCsv");

        uint256 lineStart = 0;
        uint256 lineNo = 0;
        uint256 total = 0;
        uint256 skipped = 0;
        uint256 sentBatches = 0;
        uint256[] memory ids = new uint256[](batchSize);
        address[] memory addrs = new address[](batchSize);

        console2.log("csvPath", csvPath);
        console2.log("redPacket", redPacketAddr);
        console2.log("batchSize", batchSize);

        vm.startBroadcast(pk);

        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == "\n") {
                if (i > lineStart) {
                    string memory line = _sliceString(data, lineStart, i - lineStart);
                    line = _trimCR(line);
                    if (bytes(line).length > 0) {
                        lineNo++;
                        if (lineNo > 1) {
                            string memory userIdStr = _csvColumn(line, 1);
                            string memory walletStr = _csvColumn(line, 4);
                            if (bytes(userIdStr).length == 0 || bytes(walletStr).length == 0) {
                                skipped++;
                            } else {
                                uint256 userId = vm.parseUint(userIdStr);
                                address wallet = vm.parseAddress(walletStr);

                                ids[total % batchSize] = userId;
                                addrs[total % batchSize] = wallet;
                                total++;

                                if (total % batchSize == 0) {
                                    redPacket.setParticipantsBatch(ids, addrs);
                                    sentBatches++;
                                    console2.log("batchSent", sentBatches);
                                }
                            }
                        }
                    }
                }
                lineStart = i + 1;
            }
        }

        if (total % batchSize != 0) {
            uint256 remainder = total % batchSize;
            uint256[] memory tailIds = new uint256[](remainder);
            address[] memory tailAddrs = new address[](remainder);
            for (uint256 k = 0; k < remainder; k++) {
                tailIds[k] = ids[k];
                tailAddrs[k] = addrs[k];
            }
            redPacket.setParticipantsBatch(tailIds, tailAddrs);
            sentBatches++;
            console2.log("batchSent", sentBatches);
        }
        vm.stopBroadcast();

        console2.log("lines", lineNo);
        console2.log("total", total);
        console2.log("skipped", skipped);
        console2.log("batches", sentBatches);
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
