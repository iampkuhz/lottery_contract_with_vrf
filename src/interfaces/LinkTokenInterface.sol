// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LINK 代币接口
/// @notice 用于 VRF Wrapper 的 LINK 付款调用
// 单行接口注释：LINK 代币最小接口
interface LinkTokenInterface {
    // 转账并携带数据
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
}
