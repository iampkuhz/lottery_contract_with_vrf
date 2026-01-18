// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/RedPacketVRF.sol";
import "../src/libraries/VRFV2PlusClient.sol";

/*
 * ============================================================
 * 测试流程说明
 * 1) 部署 VRF mock 与红包合约，配置管理员
 * 2) 录入参与者（含批量与逐条）
 * 3) 充值奖池并发起抽奖
 * 4) VRF 回调触发分配
 * 5) 校验分配结果与兜底逻辑
 * ============================================================
 */

/// @dev 简化版 VRF Mock，仅用于本地测试
contract VRFCoordinatorV2PlusMock {
    uint256 public nextRequestId = 1;

    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata
    ) external returns (uint256 requestId) {
        requestId = nextRequestId++;
    }

    function fulfillRandomWords(uint256 requestId, address payable consumer, uint256 randomWord) external {
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        RedPacketVRF(consumer).rawFulfillRandomWords(requestId, words);
    }
}

/// @dev 收款会失败的地址，用于测试兜底逻辑
contract RevertingReceiver {
    receive() external payable {
        revert("NO_RECEIVE");
    }
}

contract RedPacketVRFTest is Test {
    RedPacketVRF internal redPacket;
    VRFCoordinatorV2PlusMock internal coordinator;

    address internal admin = address(0xA11CE);
    address internal user1 = address(0xB0B01);
    address internal user2 = address(0xB0B02);
    address internal user3 = address(0xB0B03);

    function _formatEth6(uint256 amountWei) internal view returns (string memory) {
        uint256 whole = amountWei / 1e18;
        uint256 frac = (amountWei % 1e18) / 1e12;
        string memory fracStr = vm.toString(frac);
        if (frac < 10) {
            fracStr = string(abi.encodePacked("00000", fracStr));
        } else if (frac < 100) {
            fracStr = string(abi.encodePacked("0000", fracStr));
        } else if (frac < 1000) {
            fracStr = string(abi.encodePacked("000", fracStr));
        } else if (frac < 10000) {
            fracStr = string(abi.encodePacked("00", fracStr));
        } else if (frac < 100000) {
            fracStr = string(abi.encodePacked("0", fracStr));
        }
        return string(abi.encodePacked(vm.toString(whole), ".", fracStr));
    }

    function setUp() public {
        coordinator = new VRFCoordinatorV2PlusMock();
        redPacket = new RedPacketVRF(address(coordinator), bytes32("key"), 1);

        // owner 默认是部署者
        redPacket.addAdmin(admin);
    }

    function testBatchSetParticipantsAndDraw() public {
        // 批量录入 3 人
        uint256[] memory ids = new uint256[](3);
        address[] memory addrs = new address[](3);
        ids[0] = 101; addrs[0] = user1;
        ids[1] = 102; addrs[1] = user2;
        ids[2] = 103; addrs[2] = user3;

        uint256 gasBefore = gasleft();
        vm.prank(admin);
        redPacket.setParticipantsBatch(ids, addrs);
        emit log_named_uint("gas.setParticipantsBatch(3)", gasBefore - gasleft());

        // 充值 3 ETH
        vm.deal(address(this), 3 ether);
        gasBefore = gasleft();
        (bool ok, ) = address(redPacket).call{value: 3 ether}("");
        emit log_named_uint("gas.deposit(3 ether)", gasBefore - gasleft());
        assertTrue(ok);

        gasBefore = gasleft();
        vm.prank(admin);
        uint256 requestId = redPacket.requestDraw();
        emit log_named_uint("gas.requestDraw()", gasBefore - gasleft());
        assertTrue(redPacket.drawInProgress());

        gasBefore = gasleft();
        coordinator.fulfillRandomWords(requestId, payable(address(redPacket)), 123456);
        emit log_named_uint("gas.fulfillRandomWords()", gasBefore - gasleft());

        gasBefore = gasleft();
        vm.prank(admin);
        redPacket.distribute();
        emit log_named_uint("gas.distribute()", gasBefore - gasleft());
        assertFalse(redPacket.drawInProgress());
        assertEq(address(redPacket).balance, 0);
    }

    function testRejectContractParticipant() public {
        // 合约地址应被拒绝
        RevertingReceiver bad = new RevertingReceiver();

        uint256[] memory ids = new uint256[](1);
        address[] memory addrs = new address[](1);
        ids[0] = 201; addrs[0] = address(bad);

        vm.prank(admin);
        vm.expectRevert(bytes("ContractNotAllowed"));
        redPacket.setParticipantsBatch(ids, addrs);
    }

    function testRegister200AndDrawWithGasLogs() public {
        // 每 30 人一批次录入，模拟分批调用
        for (uint256 i = 0; i < 200; i += 30) {
            uint256 batchSize = 200 - i;
            if (batchSize > 30) {
                batchSize = 30;
            }
            uint256[] memory ids = new uint256[](batchSize);
            address[] memory addrs = new address[](batchSize);
            for (uint256 j = 0; j < batchSize; j++) {
                ids[j] = 1000 + i + j;
                addrs[j] = address(uint160(0x1000 + i + j));
            }

            uint256 gasBeforeLoop = gasleft();
            vm.prank(admin);
            redPacket.setParticipantsBatch(ids, addrs);
            emit log_named_uint("gas.setParticipantsBatch(30)", gasBeforeLoop - gasleft());
        }

        // 充值 0.1 ETH
        vm.deal(address(this), 0.1 ether);
        uint256 gasBefore = gasleft();
        (bool ok, ) = address(redPacket).call{value: 0.1 ether}("");
        emit log_named_uint("gas.deposit(0.1 ether)", gasBefore - gasleft());
        assertTrue(ok);

        // 发起抽奖并回调
        gasBefore = gasleft();
        vm.prank(admin);
        uint256 requestId = redPacket.requestDraw();
        emit log_named_uint("gas.requestDraw()", gasBefore - gasleft());

        gasBefore = gasleft();
        coordinator.fulfillRandomWords(requestId, payable(address(redPacket)), 20260117);
        emit log_named_uint("gas.fulfillRandomWords()", gasBefore - gasleft());

        gasBefore = gasleft();
        vm.prank(admin);
        redPacket.distribute();
        emit log_named_uint("gas.distribute()", gasBefore - gasleft());

        // 打印最大/最小/总和
        uint256 maxAmount = 0;
        uint256 minAmount = type(uint256).max;
        uint256 sumAmount = 0;
        for (uint256 i = 0; i < 200; i++) {
            address participant = address(uint160(0x1000 + i));
            uint256 bal = participant.balance;
            string memory line = string(
                abi.encodePacked(
                    "employeeId=",
                    vm.toString(1000 + i),
                    " amountEth=",
                    _formatEth6(bal)
                )
            );
            console.log(line);
            if (bal > maxAmount) {
                maxAmount = bal;
            }
            if (bal < minAmount) {
                minAmount = bal;
            }
            sumAmount += bal;
        }
        emit log_named_uint("result.maxAmount", maxAmount);
        emit log_named_uint("result.minAmount", minAmount);
        emit log_named_uint("result.sumAmount", sumAmount);

        if (minAmount > 0) {
            emit log_named_uint("result.maxMinRatio", maxAmount / minAmount);
            assertGt(maxAmount / minAmount, 500);
        }
        assertGe(maxAmount, 0.005 ether);
        assertEq(sumAmount, 0.1 ether);
    }
}
