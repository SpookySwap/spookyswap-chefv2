// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "./interfaces/IRewarder.sol";
import "./MasterChef.sol";
import "./MasterChefV2.sol";
import "./ChildRewarder.sol";
import "./ComplexRewarder.sol";
import "hardhat/console.sol";

contract SpookyFetchHelper {
    using SafeERC20 for IERC20;

    address public masterchef = 0x2b2929E785374c651a81A63878Ab22742656DcDd;
    address public masterchefv2 = 0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD;

    struct LpData {
      uint256 tokenBalanceInLp;
      uint256 quoteBalanceInLp;
      uint256 lpBalanceInChef;
      uint256 lpSupply;
      uint8 tokenDecimals;
      uint8 quoteDecimals;
    }

    struct RewardTokenData {
      address rewardToken;
      uint256 rewardPerSecond;
      uint256 allocPoint;
      address rewarder;
    }

    struct FarmData {
      RewardTokenData[] rewardTokens;
    }

    struct UserLpData {
      uint256 allowance;
      uint256 balance;
    }

    struct RewardEarningsData {
      address rewardToken;
      uint256 earnings;
    }

    struct UserFarmData {
      uint256 staked;
      RewardEarningsData[] earnings;
    }

    function _versionedMasterchef (uint8 version) internal view returns (address) {
      return version == 1 ? masterchef : masterchefv2;
    }

    function _tryGetChildRewarders (IRewarder rewarder) internal view returns (IRewarder[] memory) {
      if (address(rewarder) == address(0)) return new IRewarder[](0);

      try ComplexRewarder(address(rewarder)).getChildrenRewarders() returns (IRewarder[] memory childRewarders) {
        return childRewarders;
      } catch {
        return new IRewarder[](0);
      }
    }

    function _fetchMCV1PoolAlloc (uint256 pid) internal view returns (uint256 alloc) {
      (,alloc,,) = MasterChef(masterchef).poolInfo(pid);
    }
    function _fetchMCV2PoolAlloc (uint256 pid) internal view returns (uint256) {
      (,,uint64 alloc) = MasterChefV2(masterchefv2).poolInfo(pid);
      return alloc;
    }
    function _fetchIRewarderPoolAlloc (ComplexRewarder rewarder, uint256 pid) internal view returns (uint256) {
      (,,uint64 alloc) = rewarder.poolInfo(pid);
      return alloc;
    }

    function fetchLpData (IERC20 lp, IERC20 token, IERC20 quote, uint8 version) public view returns (LpData memory) {
      return LpData({
        tokenBalanceInLp: token.balanceOf(address(lp)),
        quoteBalanceInLp: quote.balanceOf(address(lp)),
        lpBalanceInChef: lp.balanceOf(_versionedMasterchef(version)),
        lpSupply: lp.totalSupply(),
        tokenDecimals: ERC20(address(token)).decimals(),
        quoteDecimals: ERC20(address(quote)).decimals()
      });
    }

    function _fetchFarmRewarders (uint256 pid, uint8 version) internal view returns (uint256, ComplexRewarder, IRewarder[] memory) {
      if (version == 1) {
        return (1, ComplexRewarder(address(0)), new IRewarder[](0));
      }
      if (version == 2) {
        ComplexRewarder rewarder = ComplexRewarder(address(MasterChefV2(masterchefv2).rewarder(pid)));
        IRewarder[] memory childRewarders = _tryGetChildRewarders(ComplexRewarder(rewarder));
        return (
          1 + (address(rewarder) != address(0) ? 1 : 0) + childRewarders.length,
          rewarder,
          childRewarders
        );
      }
      return (0, ComplexRewarder(address(0)), new IRewarder[](0));
    }

    function fetchFarmData (uint256 pid, uint8 version) public view returns (FarmData memory) {
      (uint256 rewardTokensCount, ComplexRewarder complexRewarder, IRewarder[] memory childRewarders) = _fetchFarmRewarders(pid, version);
      RewardTokenData[] memory rewardTokens = new RewardTokenData[](rewardTokensCount);


      // MCV1 pool, earns only BOO
      if (version == 1) {
        rewardTokens[0] = RewardTokenData({
          rewardToken: address(MasterChef(masterchef).boo()),
          rewardPerSecond: MasterChef(masterchef).booPerSecond(),
          allocPoint: _fetchMCV1PoolAlloc(pid),
          rewarder: masterchef
        });
      }


      // MCV2 pool, earns BOO
      if (version == 2) {
        rewardTokens[0] = RewardTokenData({
          rewardToken: address(MasterChefV2(masterchefv2).BOO()),
          rewardPerSecond: MasterChefV2(masterchefv2).booPerSecond(),
          allocPoint: _fetchMCV2PoolAlloc(pid),
          rewarder: masterchefv2
        });
      }


      // Complex Rewarder
      if (address(complexRewarder) != address(0)) {
        rewardTokens[1] = RewardTokenData({
          rewardToken: address(complexRewarder.rewardToken()),
          rewardPerSecond: complexRewarder.rewardPerSecond(),
          allocPoint: _fetchIRewarderPoolAlloc(complexRewarder, pid),
          rewarder: address(complexRewarder)
        });
      }

      // Child Rewarders of the Complex Rewarder
      for (uint8 i = 0; i < childRewarders.length; i++) {
        rewardTokens[i + 2] = RewardTokenData({
          rewardToken: address(ChildRewarder(address(childRewarders[i])).rewardToken()),
          rewardPerSecond: ChildRewarder(address(childRewarders[i])).rewardPerSecond(),
          allocPoint: _fetchIRewarderPoolAlloc(ComplexRewarder(address(childRewarders[i])), pid),
          rewarder: address(childRewarders[i])
        });
      }

      return FarmData({
        rewardTokens: rewardTokens
      });
    }

    function fetchUserLpData (address user, IERC20 lp, uint8 version) public view returns (UserLpData memory) {
      return UserLpData({
        allowance: lp.allowance(user, _versionedMasterchef(version)),
        balance: lp.balanceOf(user)
      });
    }


    function _fetchRewarderEarningsData (address user, uint256 pid, uint8 version) internal view returns (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) {
      if (version == 1) return (new IERC20[](0), new uint[](0));

      ComplexRewarder rewarder = ComplexRewarder(address(MasterChefV2(masterchefv2).rewarder(pid)));
      if (address(rewarder) == address(0)) return (new IERC20[](0), new uint[](0));

      return rewarder.pendingTokens(pid, user, 0);
    }

    function fetchUserFarmData (address user, uint256 pid, uint8 version) public view returns (UserFarmData memory) {

      // User Staked amount
      (uint256 staked,) = version == 1 ?
        MasterChef(masterchef).userInfo(pid, user) :
        MasterChefV2(masterchefv2).userInfo(pid, user);

      // If pool is v2 and has rewarder, get reward tokens and earnings
      (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) = _fetchRewarderEarningsData(user, pid, version);      

      // Return array with correct sizing
      RewardEarningsData[] memory earnings = new RewardEarningsData[](1 + rewardTokens.length);

      // Masterchef boo earnings
      earnings[0] = RewardEarningsData({
        rewardToken: address(MasterChef(masterchef).boo()),
        earnings: version == 1 ?
          MasterChef(masterchef).pendingBOO(pid, user) :
          MasterChefV2(masterchefv2).pendingBOO(pid, user)
      });

      // Complex rewarder tokens and earnings
      for (uint i = 0; i < rewardTokens.length; i++) {
        earnings[1 + i] = RewardEarningsData({
          rewardToken: address(rewardTokens[i]),
          earnings: rewardAmounts[i]
        });
      }

      return UserFarmData({
        staked: staked,
        earnings: earnings
      });
    }
}
