// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./interfaces/IRewarder.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "./MasterChefV2.sol";

contract ComplexRewarderTime is IRewarder,  Ownable{
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of REWARD entitled to the user.
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of REWARD to distribute per block.
    struct PoolInfo {
        uint accRewardPerShare;
        uint lastRewardTime;
        uint allocPoint;
    }

    /// @notice Info of each pool.
    mapping (uint => PoolInfo) public poolInfo;

    uint[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint totalAllocPoint;

    uint public rewardPerSecond;
    uint private constant ACC_TOKEN_PRECISION = 1e12;

    address private immutable MASTERCHEF_V2;

    event LogOnReward(address indexed user, uint indexed pid, uint amount, address indexed to);
    event LogPoolAddition(uint indexed pid, uint allocPoint);
    event LogSetPool(uint indexed pid, uint allocPoint);
    event LogUpdatePool(uint indexed pid, uint lastRewardTime, uint lpSupply, uint accRewardPerShare);
    event LogRewardPerSecond(uint rewardPerSecond);
    event AdminTokenRecovery(address _tokenAddress, uint _amt);
    event LogInit();

    modifier onlyMCV2 {
        require(
            msg.sender == MASTERCHEF_V2,
            "Only MCV2 can call this function."
        );
        _;
    }

    constructor (IERC20 _rewardToken, uint _rewardPerSecond, address _MASTERCHEF_V2) {
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        MASTERCHEF_V2 = _MASTERCHEF_V2;
    }


    function onReward (uint pid, address _user, address to, uint, uint lpToken) onlyMCV2 override external {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][_user];
        uint pending;
        if (user.amount > 0) {
            pending = (user.amount * pool.accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
            rewardToken.safeTransfer(to, pending);
        }
        user.amount = lpToken;
        user.rewardDebt = lpToken * pool.accRewardPerShare / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, pid, pending, to);
    }
    
    function pendingTokens(uint pid, address user, uint) override external view returns (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (rewardToken);
        uint[] memory _rewardAmounts = new uint[](1);
        _rewardAmounts[0] = pendingToken(pid, user);
        return (_rewardTokens, _rewardAmounts);
    }

    /// @notice Sets the reward per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of token to be distributed per second.
    function setRewardPerSecond(uint _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }


    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint pools) {
        pools = poolIds.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint allocPoint, uint _pid) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        uint lastRewardTime = block.timestamp;
        totalAllocPoint = totalAllocPoint + allocPoint;

        poolInfo[_pid] = PoolInfo({
            allocPoint: allocPoint,
            lastRewardTime: lastRewardTime,
            accRewardPerShare: 0
        });
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's REWARD allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint _pid, uint _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint -poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending REWARD reward for a given user.
    function pendingToken(uint _pid, address _user) public view returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint lpSupply = MasterChefV2(MASTERCHEF_V2).lpToken(_pid).balanceOf(MASTERCHEF_V2);

        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint time = block.timestamp - pool.lastRewardTime;
            uint reward = time * rewardPerSecond * pool.allocPoint / totalAllocPoint;
            accRewardPerShare = accRewardPerShare + (reward * ACC_TOKEN_PRECISION / lpSupply);
        }
        pending = (user.amount * accRewardPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint[] calldata pids) external {
        uint len = pids.length;
        for (uint i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = MasterChefV2(MASTERCHEF_V2).lpToken(pid).balanceOf(MASTERCHEF_V2);

            if (lpSupply > 0) {
                uint time = block.timestamp - pool.lastRewardTime;
                uint reward = time * rewardPerSecond * pool.allocPoint / totalAllocPoint;
                pool.accRewardPerShare = pool.accRewardPerShare + (reward * ACC_TOKEN_PRECISION / lpSupply);
            }
            pool.lastRewardTime = block.timestamp;
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accRewardPerShare);
        }
    }

    function recoverTokens(address _tokenAddress, uint _amt) external onlyOwner {        
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _amt);

        emit AdminTokenRecovery(_tokenAddress, _amt);
    }

}