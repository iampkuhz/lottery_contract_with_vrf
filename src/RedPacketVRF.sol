// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IRedPacketVRF.sol";
import "./interfaces/VRFCoordinatorV2Interface.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

/// @title 红包合约（基于 Chainlink VRF 随机数）
/// @notice 任何人可充值，管理员在指定时间点请求随机数并分配红包
/// @dev 所有注释均为中文，便于审阅与交接
contract RedPacketVRF is IRedPacketVRF {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    // -----------------------------
    // 管理员与权限
    // -----------------------------
    address public owner;
    EnumerableSet.AddressSet private adminSet;

    modifier onlyOwner() {
        require(msg.sender == owner, "OnlyOwner");
        _;
    }

    function isAdmin(address admin) public view returns (bool) {
        return adminSet.contains(admin);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "OnlyAdmin");
        _;
    }

    // -----------------------------
    // 参与者管理
    // -----------------------------
    mapping(uint256 => address) public participantById;
    EnumerableSet.UintSet private participantIds;

    // -----------------------------
    // VRF 配置与抽奖状态
    // -----------------------------
    address public immutable vrfCoordinator;
    bytes32 public immutable keyHash;
    uint64 public immutable subId;
    uint16 public constant requestConfirmations = 3;
    uint32 public constant callbackGasLimit = 1_000_000;
    uint32 public constant numWords = 1;
    uint16 public constant topPrizeBps = 500;
    uint16 public constant minPoolBps = 80;

    bool public drawInProgress;
    uint256 public lastRequestId;
    uint256 public lastRandomWord;

    // 兜底处理：转账失败的余额可领取
    mapping(address => uint256) public pendingClaims;
    // -----------------------------
    // -----------------------------
    // 构造与接收 ETH
    // -----------------------------
    constructor(address _vrfCoordinator, bytes32 _keyHash, uint64 _subId) {
        owner = msg.sender;
        _addAdmin(msg.sender);
        require(_vrfCoordinator != address(0), "ZeroCoordinator");
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subId = _subId;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // -----------------------------
    // 管理员管理
    // -----------------------------
    function addAdmin(address admin) external onlyOwner {
        _addAdmin(admin);
    }

    function removeAdmin(address admin) external onlyOwner {
        require(admin != owner, "OwnerCannotBeRemoved");
        require(adminSet.remove(admin), "NotAdmin");
        emit AdminRemoved(admin);
    }

    function getAdmins() external view returns (address[] memory) {
        return adminSet.values();
    }

    function _addAdmin(address admin) internal {
        require(admin != address(0), "ZeroAdmin");
        require(adminSet.add(admin), "AlreadyAdmin");
        emit AdminAdded(admin);
    }

    // -----------------------------
    // 参与者批量录入
    // -----------------------------
    function setParticipantsBatch(uint256[] calldata employeeIds, address[] calldata participants) external onlyAdmin {
        require(employeeIds.length == participants.length, "LengthMismatch");
        for (uint256 i = 0; i < employeeIds.length; i++) {
            _setParticipant(employeeIds[i], participants[i]);
        }
    }

    function removeParticipant(uint256 employeeId) external onlyAdmin {
        require(participantIds.contains(employeeId), "ParticipantNotFound");
        participantIds.remove(employeeId);
        delete participantById[employeeId];
        emit ParticipantRemoved(employeeId);
    }

    function getParticipantIds() external view returns (uint256[] memory) {
        return participantIds.values();
    }

    function _setParticipant(uint256 employeeId, address participant) internal {
        require(participant != address(0), "ZeroParticipant");
        require(participant.code.length == 0, "ContractNotAllowed");
        participantIds.add(employeeId);
        participantById[employeeId] = participant;
        emit ParticipantSet(employeeId, participant);
    }

    // -----------------------------
    // 抽奖流程
    // -----------------------------
    function requestDraw() external onlyAdmin returns (uint256 requestId) {
        require(!drawInProgress, "DrawInProgress");
        require(participantIds.length() > 0, "NoParticipants");
        require(address(this).balance > 0, "NoBalance");

        requestId = VRFCoordinatorV2Interface(vrfCoordinator).requestRandomWords(
            keyHash,
            subId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        drawInProgress = true;
        lastRequestId = requestId;
        emit DrawRequested(requestId);
    }

    /// @notice VRF 回调入口，只允许 coordinator 调用
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(msg.sender == vrfCoordinator, "OnlyCoordinator");
        _fulfillRandomWords(requestId, randomWords);
    }

    function _fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal {
        require(drawInProgress, "NoDraw");
        require(requestId == lastRequestId, "RequestIdMismatch");
        require(randomWords.length > 0, "NoRandom");

        lastRandomWord = randomWords[0];
        _distribute(randomWords[0]);
    }

    function _distribute(uint256 seed) internal {
        uint256 total = address(this).balance;
        uint256 count = participantIds.length();
        require(count > 0, "NoParticipants");
        require(total > 0, "NoBalance");

        uint256 topIndex = seed % count;
        uint256 minPool = (total * minPoolBps) / 10_000;
        uint256 minPer = minPool / count;
        uint256 topPrize = (total * topPrizeBps) / 10_000;
        uint256 available = total - (minPer * count);
        if (topPrize > available) {
            topPrize = available;
        }
        uint256 remaining = available - topPrize;

        uint256[] memory weights = new uint256[](count);
        uint256 weightSum = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 w = uint256(keccak256(abi.encode(seed, i))) + 1;
            weights[i] = w;
            weightSum += w;
        }

        uint256 distributed = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 employeeId = participantIds.at(i);
            address participant = participantById[employeeId];
            uint256 amount;
            if (i == count - 1) {
                amount = remaining - distributed;
            } else {
                amount = (remaining * weights[i]) / weightSum;
                distributed += amount;
            }
            amount += minPer;
            if (i == topIndex) {
                amount += topPrize;
            }
            if (amount == 0) {
                continue;
            }
            (bool ok, ) = participant.call{value: amount}("");
            if (!ok) {
                pendingClaims[participant] += amount;
                emit PendingClaim(participant, amount);
            }
            emit Allocation(participant, amount, ok);
        }

        drawInProgress = false;
        emit DrawCompleted(lastRequestId, total, count);
    }

    // -----------------------------
    // 兜底领取与紧急处理
    // -----------------------------
    function claimPending() external {
        uint256 amount = pendingClaims[msg.sender];
        require(amount > 0, "NoPending");
        pendingClaims[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ClaimFailed");
        emit Claimed(msg.sender, amount);
    }

    function emergencyWithdraw(address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "ZeroTo");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "WithdrawFailed");
        emit EmergencyWithdraw(to, amount);
    }
}
