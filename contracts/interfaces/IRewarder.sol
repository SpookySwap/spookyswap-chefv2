// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

interface IRewarder {
    using SafeERC20 for IERC20;
    function onReward(uint256 pid, address user, address recipient, uint256 Booamount, uint256 newLpAmount) external;
    function pendingTokens(uint256 pid, address user, uint256 rewardAmount) external view returns (IERC20[] memory, uint256[] memory);
}