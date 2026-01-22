// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 单行接口注释：Chainlink VRF v2.5 Wrapper 最小接口
interface IVRFV2PlusWrapper {
    /*
     * ============================================================
     * 只读状态
     * ============================================================
     */
    // 最近一次请求 ID
    function lastRequestId() external view returns (uint256);
    // 计算 LINK 支付的请求费用
    function calculateRequestPrice(uint32 callbackGasLimit, uint32 numWords) external view returns (uint256);
    // 计算原生币支付的请求费用
    function calculateRequestPriceNative(uint32 callbackGasLimit, uint32 numWords) external view returns (uint256);
    // LINK 代币地址
    function link() external view returns (address);

    /*
     * ============================================================
     * 外部接口 - 发起请求
     * ============================================================
     */
    // 使用原生币支付的随机数请求
    function requestRandomWordsInNative(
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords,
        bytes calldata extraArgs
    ) external payable returns (uint256 requestId);
}
