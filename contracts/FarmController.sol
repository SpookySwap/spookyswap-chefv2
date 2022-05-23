// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SpookyAuth.sol";
import "./interfaces/IRewarder.sol";

interface IMCV1 {
    function setBooPerSecond(uint256 _booPerSecond) external;
    function add(uint256 _allocPoint, IERC20 _lpToken) external;
    function set(uint256 _pid, uint256 _allocPoint) external;
}

interface IMCV2 {
    function add(uint64 allocPoint, IERC20 _lpToken, IRewarder _rewarder, bool update) external;
    function set(uint _pid, uint64 _allocPoint, IRewarder _rewarder, bool overwrite, bool update) external;
    function setBatch(uint[] memory _pid, uint64[] memory _allocPoint, IRewarder[] memory _rewarders, bool[] memory overwrite, bool update) external;
    function setV1HarvestQueryTime(uint256 newTime, bool inDays) external;
}

contract FarmController is SpookyAuth {

    IMCV1 MCV1;
    IMCV2 MCV2;


    constructor(address mcv1, address mcv2) {
        MCV1 = IMCV1(mcv1);
        MCV2 = IMCV2(mcv2);
    }


    // ADMIN FUNCTIONS



    //MCV2
    function add(uint64 allocPoint, IERC20 _lpToken, IRewarder _rewarder, bool update) external onlyAuth {
        MCV2.add(allocPoint, _lpToken, _rewarder, update);
    }

    /// @notice Update the given pool's BOO allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarder Addresses of the rewarder delegates.
    /// @param overwrite True if _rewarders should be `set`. Otherwise `_rewarders` is ignored.
    function set(uint _pid, uint64 _allocPoint, IRewarder _rewarder, bool overwrite, bool update) external onlyAuth {
        MCV2.set(_pid, _allocPoint, _rewarder, overwrite, update);
    }

    /// @notice Batch update the given pool's BOO allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarders Addresses of the rewarder delegates.
    /// @param overwrite True if _rewarders should be `set`. Otherwise `_rewarders` is ignored.
    function setBatch(uint[] memory _pid, uint64[] memory _allocPoint, IRewarder[] memory _rewarders, bool[] memory overwrite, bool update) external onlyAuth {
        MCV2.setBatch(_pid, _allocPoint, _rewarders, overwrite, update);
    }

    function setV1HarvestQueryTime(uint256 newTime, bool inDays) external onlyAuth {
        MCV2.setV1HarvestQueryTime(newTime, inDays);
    }

    function setBooPerSecond(uint256 _booPerSecond) external onlyAuth {
        MCV1.setBooPerSecond(_booPerSecond);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken) external onlyAuth {
        MCV1.add(_allocPoint, _lpToken);
    }

    // Update the given pool's BOO allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) external onlyAuth {
        MCV1.set(_pid, _allocPoint);
    }
}