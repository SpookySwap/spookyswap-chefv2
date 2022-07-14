// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IRewarder {
    function totalAllocPoint() external view returns (uint256);
    function rewardToken() external view returns (IERC20);
    function rewardPerSecond() external view returns (uint256);
    function onReward(uint256 pid, address user, address recipient, uint256 Booamount, uint256 newLpAmount) external;
    function pendingToken(uint _pid, address _user) external view returns (uint pending);
    function pendingTokens(uint256 pid, address user, uint256 rewardAmount) external view returns (IERC20[] memory, uint256[] memory);
}

interface IComplexRewarder is IRewarder {
    function getChildrenRewarders() external view returns (IRewarder[] memory);
}

interface IRewarderExt is IRewarder {
    function poolLength() external view returns (uint256);
    function poolIds(uint256 poolIndex) external view returns (uint256);
    function poolInfo(uint256 pid) external view returns (uint256 accRewPerShare, uint256 lastRewardTime, uint256 allocPoint);
}