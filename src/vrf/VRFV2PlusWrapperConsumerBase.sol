// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IVRFV2PlusWrapper.sol";
import "../interfaces/LinkTokenInterface.sol";

/// @title VRF v2.5 Wrapper 消费者基类
/// @notice 提供 direct funding 的请求与回调入口
// 单行合约注释：VRF v2.5 Wrapper 消费者基类
abstract contract VRFV2PlusWrapperConsumerBase {
    // 仅允许 Wrapper 回调的错误
    error OnlyVRFV2PlusWrapperCanFulfill(address have, address want);

    LinkTokenInterface internal immutable i_linkToken;
    IVRFV2PlusWrapper public immutable i_vrfV2PlusWrapper;

    // 构造函数：绑定 VRF Wrapper 地址
    constructor(address vrfV2PlusWrapper) {
        IVRFV2PlusWrapper wrapper = IVRFV2PlusWrapper(vrfV2PlusWrapper);
        i_vrfV2PlusWrapper = wrapper;
        i_linkToken = LinkTokenInterface(wrapper.link());
    }

    // LINK 支付请求（如需）
    function requestRandomness(
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords,
        bytes memory extraArgs
    ) internal returns (uint256 requestId, uint256 requestPrice) {
        requestPrice = i_vrfV2PlusWrapper.calculateRequestPrice(callbackGasLimit, numWords);
        i_linkToken.transferAndCall(
            address(i_vrfV2PlusWrapper),
            requestPrice,
            abi.encode(callbackGasLimit, requestConfirmations, numWords, extraArgs)
        );
        requestId = i_vrfV2PlusWrapper.lastRequestId();
    }

    // 原生币支付请求
    function requestRandomnessPayInNative(
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords,
        bytes memory extraArgs
    ) internal returns (uint256 requestId, uint256 requestPrice) {
        requestPrice = i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, numWords);
        requestId = i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(
            callbackGasLimit,
            requestConfirmations,
            numWords,
            extraArgs
        );
    }

    // Wrapper 回调入口
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external virtual {
        if (msg.sender != address(i_vrfV2PlusWrapper)) {
            revert OnlyVRFV2PlusWrapperCanFulfill(msg.sender, address(i_vrfV2PlusWrapper));
        }
        fulfillRandomWords(requestId, randomWords);
    }

    // 随机数回调处理
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;
}
