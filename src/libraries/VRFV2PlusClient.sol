// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 单行接口注释：VRF v2.5 请求参数编码工具
library VRFV2PlusClient {
    // 额外参数编码标识
    bytes4 public constant EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));

    // VRF 请求结构体
    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    // 额外参数结构体
    struct ExtraArgsV1 {
        bool nativePayment;
    }

    // 将额外参数编码为 bytes
    function _argsToBytes(ExtraArgsV1 memory extraArgs) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs);
    }
}
