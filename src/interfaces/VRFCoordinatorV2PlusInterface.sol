// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/VRFV2PlusClient.sol";

// 单行接口注释：Chainlink VRF v2.5 Coordinator 最小接口
interface VRFCoordinatorV2PlusInterface {
    // 请求随机数
    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata request
    ) external returns (uint256 requestId);
}
