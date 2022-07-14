// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRewarder.sol";
import "./interfaces/IMasterChef.sol";

contract SpookyFetchHelper {
    using SafeERC20 for IERC20;

    uint256 secPerYear = 31536000;

    address public masterchef = 0x2b2929E785374c651a81A63878Ab22742656DcDd;
    address public masterchefv2 = 0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD;
    address public masterchefv3 = 0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD; // TODO: Update to real address
    address[3] public chefs = [masterchef, masterchefv2, masterchefv3];

    mapping(address => uint256) public dummyPids;

    struct RewardTokenData {
        address rewardToken;
        uint256 rewardPerYear;
    }

    struct RewardEarningsData {
        address rewardToken;
        uint256 earnings;
    }

    constructor() {
        dummyPids[masterchefv2] = 73;
        // dummyPids[masterchefv3] = 81;
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
        totalAlloc = _fetchMCV1PoolAlloc(dummyPids[chef]);
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
        IRewarderExt rewExt = IRewarderExt(address(rewarder));
        uint256 alloc;
        for (uint256 i = 0; i < rewExt.poolLength(); i++) {
            (,,alloc) = rewExt.poolInfo(rewExt.poolIds(i));
            totalAlloc += alloc;
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
        if (version == 1) {
            rewardTokens[0] = RewardTokenData({
                rewardToken: address(IMasterChef(masterchef).boo()),
                rewardPerYear: (secPerYear *
                    IMasterChef(masterchef).booPerSecond() *
                    _fetchMCV1PoolAlloc(pid)) / _fetchMCV1TotalAlloc()
            });
        }

        // MCV2 pool, earns BOO
        if (version == 2 || version == 3) {
            uint256 totalAlloc = _fetchMCV2TotalAlloc(chefs[version]);
            rewardTokens[0] = RewardTokenData({
                rewardToken: address(IMasterChefV2(chefs[version]).BOO()),
                rewardPerYear: totalAlloc == 0
                    ? 0
                    : (secPerYear *
                        IMasterChefV2(chefs[version]).booPerSecond() *
                        _fetchMCV2PoolAlloc(chefs[version], pid)) / totalAlloc
            });
        }

        // Complex Rewarder
        if (address(complexRewarder) != address(0)) {
            uint256 totalAlloc = _fetchIRewarderTotalAlloc(complexRewarder);
            rewardTokens[1] = RewardTokenData({
                rewardToken: address(complexRewarder.rewardToken()),
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
        uint256 booEarnings;
        if (version == 1)
            booEarnings = IMasterChef(masterchef).pendingBOO(pid, user);
        if (version == 2 || version == 3)
            booEarnings = IMasterChefV2(chefs[version]).pendingBOO(pid, user);
        earnings[0] = RewardEarningsData({
            rewardToken: address(IMasterChef(masterchef).boo()),
            earnings: booEarnings
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
