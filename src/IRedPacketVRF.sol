// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title 红包合约接口（基于 Chainlink VRF 随机数）
/// @notice 外部交互的接口定义与事件声明
// 单行接口注释：对外暴露的红包合约接口
interface IRedPacketVRF {
    // 事件

    /*
     * ============================================================
     * 事件 - 充值相关
     * ============================================================
     */
    // 单次充值到账事件
    event Deposit(address indexed from, uint256 amount);

    /*
     * ============================================================
     * 事件 - 管理员与紧急处理
     * ============================================================
     */
    // 新增管理员事件
    event AdminAdded(address indexed admin);
    // 移除管理员事件
    event AdminRemoved(address indexed admin);
    // 紧急提款事件
    event EmergencyWithdraw(address indexed to, uint256 amount);

    /*
     * ============================================================
     * 事件 - 参与者相关
     * ============================================================
     */
    // 参与者地址设置事件
    event ParticipantSet(uint256 indexed employeeId, address indexed participant);
    // 参与者移除事件
    event ParticipantRemoved(uint256 indexed employeeId);

    /*
     * ============================================================
     * 事件 - 抽奖流程
     * ============================================================
     */
    // 抽奖请求发起事件
    event DrawRequested(uint256 indexed requestId);
    // 抽奖完成事件
    event DrawCompleted(uint256 indexed requestId, uint256 totalAmount, uint256 participantCount);

    /*
     * ============================================================
     * 事件 - 分配与兜底
     * ============================================================
     */
    // 单个参与者分配结果事件
    event Allocation(address indexed participant, uint256 amount, bool success);
    // 转账失败记录待领取事件
    event PendingClaim(address indexed participant, uint256 amount);
    // 领取待领取金额事件
    event Claimed(address indexed participant, uint256 amount);

    // 只读状态

    /*
     * ============================================================
     * 只读状态 - 权限与参与者
     * ============================================================
     */
    // 合约拥有者地址
    function owner() external view returns (address);
    // 是否为管理员
    function isAdmin(address admin) external view returns (bool);
    // 工号对应参与者地址
    function participantById(uint256 employeeId) external view returns (address);

    /*
     * ============================================================
     * 只读状态 - VRF 与抽奖状态
     * ============================================================
     */
    // 当前 VRF Wrapper 地址
    function vrfWrapper() external view returns (address);
    // VRF 请求确认数
    function requestConfirmations() external view returns (uint16);
    // VRF 回调 gas 上限
    function callbackGasLimit() external view returns (uint32);
    // VRF 随机词数量
    function numWords() external view returns (uint32);
    // VRF 是否使用原生币支付
    function useNativePayment() external view returns (bool);
    // VRF 预估请求费用（原生币）
    function getRequestPriceNative() external view returns (uint256);
    // 头奖最小占比（bps）
    function minTopBps() external view returns (uint16);
    // 权重取值位数
    function weightBits() external view returns (uint16);
    // 是否处于抽奖中
    function drawInProgress() external view returns (bool);
    // 随机数是否已就绪
    function randomReady() external view returns (bool);
    // 最近一次请求 ID
    function lastRequestId() external view returns (uint256);
    // 最近一次随机数
    function lastRandomWord() external view returns (uint256);

    /*
     * ============================================================
     * 只读状态 - 分配结果与兜底金额
     * ============================================================
     */
    // 参与者待领取金额
    function pendingClaims(address participant) external view returns (uint256);
    // 获取参与者最终分配金额映射
    function getParticipantAmountMapping() external view returns (address[] memory participants, uint256[] memory amounts);
    // 获取参与者工号列表
    function getParticipantIds() external view returns (uint256[] memory);
    // 获取参与者工号与地址映射
    function getParticipantAddressMapping() external view returns (uint256[] memory ids, address[] memory addrs);

    // 外部接口
    // 直接转账充值入口
    receive() external payable;

    /*
     * ============================================================
     * 外部接口 - 管理员与紧急处理
     * ============================================================
     */
    // 添加管理员
    function addAdmin(address admin) external;
    // 移除管理员
    function removeAdmin(address admin) external;
    // 获取管理员列表
    function getAdmins() external view returns (address[] memory);
    // 管理员紧急提现
    function emergencyWithdraw(address to, uint256 amount) external;

    /*
     * ============================================================
     * 外部接口 - 参与者管理
     * ============================================================
     */
    // 批量设置参与者
    function setParticipantsBatch(uint256[] calldata employeeIds, address[] calldata participants) external;
    // 移除参与者
    function removeParticipant(uint256 employeeId) external;

    /*
     * ============================================================
     * 外部接口 - 抽奖流程
     * ============================================================
     */
    // 发起抽奖请求
    function requestDraw() external payable returns (uint256 requestId);
    // VRF 回调入口
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
    // 管理员触发分配
    function distribute() external;

    /*
     * ============================================================
     * 外部接口 - 兜底领取
     * ============================================================
     */
    // 领取待领取金额
    function claimPending() external;
}
