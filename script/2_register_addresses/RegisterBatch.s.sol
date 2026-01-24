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
 *   time forge script script/2_register_addresses/RegisterBatch.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *   若 BATCH_SIZE=0 启用自动估算批次，请加上 --ffi
 *
 * 依赖环境变量：
 *   RPC_URL
 *   PRIVATE_KEY
 *   RED_PACKET
 *   BATCH_SIZE（可选，设置为 0 启用自动估算）
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
    uint256 private constant MAX_AUTO_BATCH_SIZE = 500;

    struct CsvContext {
        uint256 lineNo;
        uint256 total;
        uint256 skipped;
        uint256 sentBatches;
        uint256 chunkIdx;
        uint256 lineStart;
    }

    function run() external {
        console2.log("run.start");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address redPacketAddr = vm.envAddress("RED_PACKET");
        uint256 batchSize = vm.envOr("BATCH_SIZE", uint256(0));
        bool forceSubmit = vm.envOr("FORCE_SUBMIT", uint256(0)) == 1;
        string memory csvPath = vm.envOr("CSV_PATH", string("data/participants.csv"));

        require(redPacketAddr != address(0), "ZeroRedPacket");
        if (batchSize == 0) {
            batchSize = _autoBatchSize(redPacketAddr, 6_000_000);
        }
        require(batchSize > 0, "ZeroBatchSize");

        RedPacketVRF redPacket = RedPacketVRF(payable(redPacketAddr));
        bytes memory data = bytes(vm.readFile(csvPath));
        require(data.length > 0, "EmptyCsv");

        console2.log("csvPath", csvPath);
        console2.log("redPacket", redPacketAddr);
        console2.log("batchSize", batchSize);
        console2.log("forceSubmit", forceSubmit);
        console2.log("csvBytes", data.length);
        vm.startBroadcast(pk);
        (uint256 lineNo, uint256 total, uint256 skipped, uint256 sentBatches) =
            _sendBatchesFromCsv(redPacket, data, batchSize, forceSubmit);
        vm.stopBroadcast();

        console2.log("lines", lineNo);
        console2.log("total", total);
        console2.log("skipped", skipped);
        console2.log("batches", sentBatches);
    }

    function _autoBatchSize(address redPacketAddr, uint256 maxBatchGas) internal returns (uint256 batchSize) {
        string memory rpcUrl = vm.envString("RPC_URL");
        uint256 low = 1;
        uint256 high = 1;

        while (high < MAX_AUTO_BATCH_SIZE) {
            uint256 gasEstimate = _estimateBatchGas(redPacketAddr, high, rpcUrl);
            if (gasEstimate == 0 || gasEstimate > maxBatchGas) {
                break;
            }
            low = high;
            high = high * 2;
        }
        if (high > MAX_AUTO_BATCH_SIZE) {
            high = MAX_AUTO_BATCH_SIZE;
        }
        if (high == low) {
            return low;
        }

        while (low + 1 < high) {
            uint256 mid = (low + high) / 2;
            uint256 gasEstimate = _estimateBatchGas(redPacketAddr, mid, rpcUrl);
            if (gasEstimate == 0 || gasEstimate > maxBatchGas) {
                high = mid;
            } else {
                low = mid;
            }
        }
        batchSize = low;
    }

    function _estimateBatchGas(address redPacketAddr, uint256 size, string memory rpcUrl) internal returns (uint256) {
        uint256[] memory ids = new uint256[](size);
        address[] memory addrs = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            ids[i] = 1_000_000 + i;
            addrs[i] = address(uint160(0x1000 + i));
        }
        bytes memory callData = abi.encodeCall(RedPacketVRF.setParticipantsBatch, (ids, addrs));
        string memory dataHex = _bytesToHex(callData);

        string[] memory cmd = new string[](8);
        cmd[0] = "cast";
        cmd[1] = "estimate";
        cmd[2] = "--rpc-url";
        cmd[3] = rpcUrl;
        cmd[4] = "--to";
        cmd[5] = vm.toString(redPacketAddr);
        cmd[6] = "--data";
        cmd[7] = dataHex;
        bytes memory out = vm.ffi(cmd);
        return vm.parseUint(string(out));
    }

    function _sendBatchesFromCsv(
        RedPacketVRF redPacket,
        bytes memory data,
        uint256 batchSize,
        bool forceSubmit
    ) internal returns (uint256 lineNo, uint256 total, uint256 skipped, uint256 sentBatches) {
        CsvContext memory ctx;
        uint256[] memory chunkIds = new uint256[](batchSize);
        address[] memory chunkAddrs = new address[](batchSize);

        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == "\n") {
                if (i > ctx.lineStart) {
                    string memory line = _sliceString(data, ctx.lineStart, i - ctx.lineStart);
                    line = _trimCR(line);
                    if (bytes(line).length > 0) {
                        ctx.lineNo++;
                        if (ctx.lineNo > 1) {
                            (bool ok, uint256 userId, address wallet) = _parseLine(line);
                            if (!ok || userId == 0 || wallet == address(0)) {
                                if (forceSubmit) {
                                    ctx.skipped++;
                                } else {
                                    require(ok, "InvalidCsvLine");
                                    require(userId > 0, "InvalidUserId");
                                    require(wallet != address(0), "InvalidWallet");
                                }
                            } else {
                                chunkIds[ctx.chunkIdx] = userId;
                                chunkAddrs[ctx.chunkIdx] = wallet;
                                ctx.chunkIdx++;
                                ctx.total++;
                                if (ctx.chunkIdx == batchSize) {
                                    redPacket.setParticipantsBatch(chunkIds, chunkAddrs);
                                    ctx.sentBatches++;
                                    console2.log("batchSent", ctx.sentBatches);
                                    ctx.chunkIdx = 0;
                                }
                            }
                        }
                    }
                }
                ctx.lineStart = i + 1;
            }
        }

        if (ctx.chunkIdx > 0) {
            uint256[] memory tailIds = new uint256[](ctx.chunkIdx);
            address[] memory tailAddrs = new address[](ctx.chunkIdx);
            for (uint256 i = 0; i < ctx.chunkIdx; i++) {
                tailIds[i] = chunkIds[i];
                tailAddrs[i] = chunkAddrs[i];
            }
            redPacket.setParticipantsBatch(tailIds, tailAddrs);
            ctx.sentBatches++;
            console2.log("batchSent", ctx.sentBatches);
        }
        return (ctx.lineNo, ctx.total, ctx.skipped, ctx.sentBatches);
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

    function _bytesToHex(bytes memory data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory out = new bytes(2 + data.length * 2);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            uint8 b = uint8(data[i]);
            out[2 + i * 2] = hexChars[b >> 4];
            out[3 + i * 2] = hexChars[b & 0x0f];
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
