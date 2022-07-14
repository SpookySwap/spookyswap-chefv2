// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRewarder.sol";

interface IMasterChef {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. BOO to distribute per second.
        uint256 lastRewardBlock; // Last block number that SUSHI distribution occurs.
        uint256 accBooPerShare; // Accumulated BOO per share, times 1e12. See below.
    }

    function boo() external view returns (IERC20);

    function userInfo(uint256 pid, address user)
        external
        view
        returns (IMasterChef.UserInfo memory);

    function poolInfo(uint256 pid)
        external
        view
        returns (IMasterChef.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function booPerSecond() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function pendingBOO(uint256 pid, address user)
        external
        view
        returns (uint256);
}

interface IMasterChefV2 {
    function userInfo(uint256 pid, address user)
        external
        view
        returns (uint256 amount, uint256 rewardDebt);

    function poolInfo(uint256 pid)
        external
        view
        returns (
            uint256 accBooPerShare,
            uint256 lastRewardTime,
            uint256 allocPoint
        );

    function rewarder(uint256 pid) external view returns (IRewarder);

    function booPerSecond() external view returns (uint256);

    function BOO() external view returns (IERC20);

    function pendingBOO(uint256 pid, address user)
        external
        view
        returns (uint256);
}
