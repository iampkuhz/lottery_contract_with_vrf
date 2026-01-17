// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/RedPacketVRF.sol";

/// @dev 简化版 VRF Mock，仅用于本地测试
contract VRFCoordinatorV2Mock {
    uint256 public nextRequestId = 1;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external returns (uint256 requestId) {
        requestId = nextRequestId++;
    }

    function fulfillRandomWords(uint256 requestId, address consumer, uint256 randomWord) external {
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
    VRFCoordinatorV2Mock internal coordinator;

    address internal admin = address(0xA11CE);
    address internal user1 = address(0xB0B01);
    address internal user2 = address(0xB0B02);
    address internal user3 = address(0xB0B03);

    function setUp() public {
        coordinator = new VRFCoordinatorV2Mock();
        redPacket = new RedPacketVRF(address(coordinator), bytes32("key"), 1);

        // owner 默认是部署者
        redPacket.addAdmin(admin);
    }

    function testBatchSetParticipantsAndDraw() public {
        uint256[] memory ids = new uint256[](3);
        address[] memory addrs = new address[](3);
        ids[0] = 101; addrs[0] = user1;
        ids[1] = 102; addrs[1] = user2;
        ids[2] = 103; addrs[2] = user3;

        vm.prank(admin);
        redPacket.setParticipantsBatch(ids, addrs);

        // 充值 3 ETH
        vm.deal(address(this), 3 ether);
        (bool ok, ) = address(redPacket).call{value: 3 ether}("");
        assertTrue(ok);

        vm.prank(admin);
        uint256 requestId = redPacket.requestDraw();
        assertTrue(redPacket.drawInProgress());

        coordinator.fulfillRandomWords(requestId, address(redPacket), 123456);
        assertFalse(redPacket.drawInProgress());
        assertEq(address(redPacket).balance, 0);
    }

    function testPendingClaimWhenTransferFails() public {
        RevertingReceiver bad = new RevertingReceiver();

        uint256[] memory ids = new uint256[](2);
        address[] memory addrs = new address[](2);
        ids[0] = 201; addrs[0] = address(bad);
        ids[1] = 202; addrs[1] = user2;

        vm.prank(admin);
        redPacket.setParticipantsBatch(ids, addrs);

        vm.deal(address(this), 2 ether);
        (bool ok, ) = address(redPacket).call{value: 2 ether}("");
        assertTrue(ok);

        vm.prank(admin);
        uint256 requestId = redPacket.requestDraw();
        coordinator.fulfillRandomWords(requestId, address(redPacket), 999);

        // bad 收不到钱，会记录到 pendingClaims
        uint256 pending = redPacket.pendingClaims(address(bad));
        assertGt(pending, 0);

        // 好地址应能收到部分余额
        assertGt(user2.balance, 0);
    }
}
