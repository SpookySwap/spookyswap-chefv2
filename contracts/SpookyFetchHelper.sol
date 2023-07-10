// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRewarder.sol";
import "./interfaces/IMasterChef.sol";

contract SpookyFetchHelper {
    uint256 secPerYear = 31536000;

    address public masterchef = 0x6A8C15229FFD048dcffF3D05EaA5C1A70e6c599C;
    address public masterchefv2 = 0x29822044a7AD0F6B19A6CdCa1c82014785bFBa7e;
    address public masterchefv3 = 0x29822044a7AD0F6B19A6CdCa1c82014785bFBa7e;

    mapping(uint8 => address) public chefs;
    mapping(address => uint256) public dummyPids;

    struct RewardTokenData {
        address rewardToken;
        uint256 allocPoint;
        uint256 rewardPerYear;
    }

    struct RewardEarningsData {
        address rewardToken;
        uint256 earnings;
    }

    constructor() {
        dummyPids[masterchefv2] = 0;
        dummyPids[masterchefv3] = 0;
        chefs[1] = masterchef;
        chefs[2] = masterchefv2;
        chefs[3] = masterchefv3;
    }

    function _tryTokenDecimals(IERC20 token) internal view returns (uint8) {
        try ERC20(address(token)).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            return 0;
        }
    }

    function _tryGetChildRewarders(IRewarder rewarder)
    internal
    view
    returns (IRewarder[] memory)
    {
        if (address(rewarder) == address(0)) return new IRewarder[](0);

        try IComplexRewarder(address(rewarder)).getChildrenRewarders() returns (
            IRewarder[] memory childRewarders
        ) {
            return childRewarders;
        } catch {
            return new IRewarder[](0);
        }
    }

    function _fetchMCV1PoolAlloc(uint256 pid)
    internal
    view
    returns (uint256 alloc)
    {
        alloc = IMasterChef(masterchef).poolInfo(pid).allocPoint;
    }

    function _fetchMCV1TotalAlloc() internal view returns (uint256 totalAlloc) {
        totalAlloc = IMasterChef(masterchef).totalAllocPoint();
    }

    function _fetchMCV2PoolAlloc(address chef, uint256 pid)
    internal
    view
    returns (uint256 alloc)
    {
        (, , alloc) = IMasterChefV2(chef).poolInfo(pid);
    }

    function _fetchMCV2TotalAlloc(address chef)
    internal
    view
    returns (uint256 totalAlloc)
    {
        totalAlloc = IMasterChefV2(chef).totalAllocPoint();
    }

    function _fetchIRewarderPoolAlloc(IRewarder rewarder, uint256 pid)
    internal
    view
    returns (uint256 alloc)
    {
        (, , alloc) = IRewarderExt(address(rewarder)).poolInfo(pid);
    }

    function _fetchIRewarderTotalAlloc(IRewarder rewarder)
    internal
    view
    returns (uint256 totalAlloc)
    {
        try IRewarderExt(address(rewarder)).totalAllocPoint() returns (
            uint256 alloc
        ) {
            totalAlloc = alloc;
        } catch {
            uint256 alloc;
            for (uint256 i = 0; i < IRewarderExt(address(rewarder)).poolLength(); i++) {
                (,,alloc) = IRewarderExt(address(rewarder)).poolInfo(IRewarderExt(address(rewarder)).poolIds(i));
                totalAlloc += alloc;
            }
        }
    }

    function fetchLpData(
        IERC20 lp,
        IERC20 token,
        IERC20 quote,
        uint8 version
    )
    public
    view
    returns (
        uint256 tokenBalanceInLp,
        uint256 quoteBalanceInLp,
        uint256 lpBalanceInChef,
        uint256 lpSupply,
        uint8 tokenDecimals,
        uint8 quoteDecimals
    )
    {
        tokenBalanceInLp = token.balanceOf(address(lp));
        quoteBalanceInLp = quote.balanceOf(address(lp));
        lpBalanceInChef = lp.balanceOf(chefs[version]);
        lpSupply = lp.totalSupply();
        tokenDecimals = _tryTokenDecimals(token);
        quoteDecimals = _tryTokenDecimals(quote);
    }

    function _fetchFarmRewarders(uint256 pid, uint8 version)
    internal
    view
    returns (
        uint256,
        IRewarder,
        IRewarder[] memory
    )
    {
        if (version == 1) {
            return (1, IRewarder(address(0)), new IRewarder[](0));
        }
        if (version == 2 || version == 3) {
            IRewarder rewarder = IMasterChefV2(chefs[version]).rewarder(pid);
            IRewarder[] memory childRewarders = _tryGetChildRewarders(rewarder);
            return (
            1 +
            (address(rewarder) != address(0) ? 1 : 0) +
            childRewarders.length,
            rewarder,
            childRewarders
            );
        }

        return (0, IRewarder(address(0)), new IRewarder[](0));
    }

    function fetchFarmData(uint256 pid, uint8 version)
    public
    view
    returns (RewardTokenData[] memory rewardTokens)
    {
        (
        uint256 rewardTokensCount,
        IRewarder complexRewarder,
        IRewarder[] memory childRewarders
        ) = _fetchFarmRewarders(pid, version);
        rewardTokens = new RewardTokenData[](rewardTokensCount);

        // MCV1 pool, earns only BOO
        rewardTokens[0] = RewardTokenData({
            rewardToken: 0x0000000000000000000000000000000000000000,
            allocPoint: 0,
            rewardPerYear: 0
            });

        // Complex Rewarder
        if (address(complexRewarder) != address(0)) {
            uint256 totalAlloc = _fetchIRewarderTotalAlloc(complexRewarder);
            rewardTokens[1] = RewardTokenData({
            rewardToken: address(complexRewarder.rewardToken()),
            allocPoint: _fetchIRewarderPoolAlloc(complexRewarder, pid),
            rewardPerYear: totalAlloc == 0
                ? 0
                : (secPerYear *
                complexRewarder.rewardPerSecond() *
                _fetchIRewarderPoolAlloc(complexRewarder, pid)) /
                totalAlloc
            });
        }

        // Child Rewarders of the Complex Rewarder
        for (uint8 i = 0; i < childRewarders.length; i++) {
            uint256 totalAlloc = _fetchIRewarderTotalAlloc(childRewarders[i]);
            rewardTokens[i + 2] = RewardTokenData({
            rewardToken: address(childRewarders[i].rewardToken()),
            allocPoint: _fetchIRewarderPoolAlloc(childRewarders[i], pid),
            rewardPerYear: totalAlloc == 0
                ? 0
                : (secPerYear *
                childRewarders[i].rewardPerSecond() *
                _fetchIRewarderPoolAlloc(childRewarders[i], pid)) /
                totalAlloc
            });
        }
    }

    function fetchUserLpData(
        address user,
        IERC20 lp,
        uint8 version
    ) public view returns (uint256 allowance, uint256 balance) {
        allowance = lp.allowance(user, chefs[version]);
        balance = lp.balanceOf(user);
    }

    function _fetchRewarderEarningsData(
        address user,
        uint256 pid,
        uint8 version
    )
    internal
    view
    returns (IERC20[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        if (version == 1) return (new IERC20[](0), new uint256[](0));

        IRewarder rewarder = IMasterChefV2(chefs[version]).rewarder(pid);
        if (address(rewarder) == address(0))
            return (new IERC20[](0), new uint256[](0));

        return rewarder.pendingTokens(pid, user, 0);
    }

    function fetchUserFarmData(
        address user,
        uint256 pid,
        uint8 version
    )
    public
    view
    returns (uint256 staked, RewardEarningsData[] memory earnings)
    {
        // User Staked amount
        if (version == 1)
            staked = IMasterChef(masterchef).userInfo(pid, user).amount;
        if (version == 2 || version == 3)
            (staked, ) = IMasterChefV2(chefs[version]).userInfo(pid, user);

        // If pool is v2 and has rewarder, get reward tokens and earnings
        (
        IERC20[] memory rewardTokens,
        uint256[] memory rewardAmounts
        ) = _fetchRewarderEarningsData(user, pid, version);

        // Return array with correct sizing
        earnings = new RewardEarningsData[](1 + rewardTokens.length);

        // Masterchef boo earnings
        earnings[0] = RewardEarningsData({
        rewardToken: 0x0000000000000000000000000000000000000000,
        earnings: 0
        });

        // Complex rewarder tokens and earnings
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            earnings[1 + i] = RewardEarningsData({
            rewardToken: address(rewardTokens[i]),
            earnings: rewardAmounts[i]
            });
        }
    }
}