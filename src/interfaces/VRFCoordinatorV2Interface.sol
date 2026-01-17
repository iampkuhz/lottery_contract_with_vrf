// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 单行接口注释：Chainlink VRF v2 Coordinator 最小接口
interface VRFCoordinatorV2Interface {
    // 请求随机数
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId);
}
