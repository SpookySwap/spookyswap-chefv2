// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "./interfaces/IRewarder.sol";
import "./interfaces/IMasterChef.sol";


/// @notice The (older) MasterChef contract gives out a constant number of BOO tokens per second.
/// It is the only address with minting rights for BOO.
/// The idea for this MasterChef V2 (MCV2) contract is therefore to be the owner of a dummy token
/// that is deposited into the MasterChef V1 (MCV1) contract.
/// The allocation point for this pool on MCV1 is the total allocation point for all pools that receive double incentives.
contract MasterChefV2 is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of BOO entitled to the user.
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of BOO to distribute per second.
    struct PoolInfo {
        uint128 accBooPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Address of MCV1 contract.
    IMasterChef public immutable MASTER_CHEF;
    /// @notice Address of BOO contract.
    IERC20 public immutable BOO;
    /// @notice The index of MCV2 master pool in MCV1.
    uint public immutable MASTER_PID;

    /// @notice Info of each MCV2 pool.
    mapping (uint => PoolInfo) public poolInfo;
    /// @notice Address of the LP token for each MCV2 pool.
    mapping (uint => IERC20) public lpToken;
    /// @notice Amount of pool infos and their respective lpToken entries I.E stores last ID + 1, for above two mappings
    uint public poolInfoAmount;
    /// @notice Is an address contained in the above `lpToken` array
    mapping(address => bool) public isLpToken;
    /// @notice Address of each `IRewarder` contract in MCV2.
    mapping(uint => IRewarder[]) public rewarders;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint;

    uint private constant ACC_BOO_PRECISION = 1e12;

    /// @dev Last MCV1 harvest timestamp.
    uint public lastV1HarvestTimestamp;
    /// @dev How often v1 harvest should be called by the query function
    uint public V1_HARVEST_QUERY_TIME = 1 days;

    event Deposit(address indexed user, uint indexed pid, uint amount, address indexed to);
    event Withdraw(address indexed user, uint indexed pid, uint amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint amount, address indexed to);
    event Harvest(address indexed user, uint indexed pid, uint amount);
    event LogPoolAddition(uint indexed pid, uint allocPoint, IERC20 indexed lpToken, IRewarder[] rewarders, bool update);
    event LogSetPool(uint indexed pid, uint allocPoint, IRewarder[] rewarders, bool overwrite, bool update);
    event LogUpdatePool(uint indexed pid, uint lastRewardTime, uint lpSupply, uint accBooPerShare);
    event LogInit();

    /// @param _MASTER_CHEF The SpookySwap MCV1 contract address.
    /// @param _boo The BOO token contract address.
    /// @param _MASTER_PID The pool ID of the dummy token on the base MCV1 contract.
    constructor(IMasterChef _MASTER_CHEF, IERC20 _boo, uint _MASTER_PID) {
        MASTER_CHEF = _MASTER_CHEF;
        BOO = _boo;
        MASTER_PID = _MASTER_PID;
    }

    /// @notice Deposits a dummy token to `MASTER_CHEF` MCV1. This is required because MCV1 holds the minting rights for BOO.
    /// Any balance of transaction sender in `dummyToken` is transferred.
    /// The allocation point for the pool on MCV1 is the total allocation point for all pools that receive double incentives.
    /// @param dummyToken The address of the ERC-20 token to deposit into MCV1.
    function init(IERC20 dummyToken) external {
        uint balance = dummyToken.balanceOf(msg.sender);
        require(balance != 0, "MasterChefV2: Balance must exceed 0");
        dummyToken.safeTransferFrom(msg.sender, address(this), balance);
        dummyToken.approve(address(MASTER_CHEF), balance);
        MASTER_CHEF.deposit(MASTER_PID, balance);
        emit LogInit();
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint pools) {
        pools = poolInfoAmount;
    }

    function checkForDuplicate(IERC20 _lpToken) internal view {
        require(!isLpToken[address(_lpToken)], "add: pool already exists!!!!");
    }

    modifier validatePid(uint256 pid) {
        require(pid < poolInfoAmount, "pid doesn't exist...");
        _;
    }

    

    /// @notice View function to see pending BOO on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending BOO reward for a given user.
    function pendingBoo(uint _pid, address _user) external view validatePid(_pid) returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accBooPerShare = pool.accBooPerShare;
        uint lpSupply = lpToken[_pid].balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint multiplier = block.timestamp - pool.lastRewardTime;
            uint booReward = totalAllocPoint == 0 ? 0 : ((multiplier * booPerSecond() * pool.allocPoint) / totalAllocPoint);
            accBooPerShare = accBooPerShare + (booReward * ACC_BOO_PRECISION / lpSupply);
        }
        pending = (user.amount * accBooPerShare / ACC_BOO_PRECISION) - user.rewardDebt;
    }

    /// @notice Update reward variables for an array of pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        harvestFromMasterChef();
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            _updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @dev This function should never be called from a smart contract as it has an unbounded gas cost.
    function massUpdateAllPools() public {
        harvestFromMasterChef();
        uint len = poolInfoAmount;
        for (uint pid = 0; pid < len; ++pid) {
            _updatePool(pid);
        }
    }

    /// @notice Calculates and returns the `amount` of BOO per second allocated to this contract
    function booPerSecond() public view returns (uint amount) {
        amount = MASTER_CHEF.booPerSecond() * MASTER_CHEF.poolInfo(MASTER_PID).allocPoint / MASTER_CHEF.totalAllocPoint();
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function _updatePool(uint pid) internal validatePid(pid) returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = lpToken[pid].balanceOf(address(this));
            if (lpSupply > 0) {
                uint multiplier = block.timestamp - pool.lastRewardTime;
                uint booReward = totalAllocPoint == 0 ? 0 : ((multiplier * booPerSecond() * pool.allocPoint) / totalAllocPoint);
                queryHarvestFromMasterChef();
                pool.accBooPerShare = uint128(pool.accBooPerShare + ((booReward * ACC_BOO_PRECISION) / lpSupply));
            }
            pool.lastRewardTime = uint64(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accBooPerShare);
        }
    }

    function updatePool(uint pid) external returns (PoolInfo memory pool) {
        return _updatePool(pid);
    }

    function deposit(uint pid, uint amount, address to) external validatePid(pid) {
        _deposit(pid, amount, to);
    }

    function deposit(uint pid, uint amount) external validatePid(pid) {
        _deposit(pid, amount, msg.sender);
    }


    /// @notice Deposit LP tokens to MCV2 for BOO allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function _deposit(uint pid, uint amount, address to) internal {
        PoolInfo memory pool = _updatePool(pid);
        UserInfo storage user = userInfo[pid][to];

        // Effects
        uint256 _pendingBoo = (user.amount * (pool.accBooPerShare / ACC_BOO_PRECISION)) - user.rewardDebt;

        user.amount += amount;
        user.rewardDebt = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;

        // Interactions
        if (_pendingBoo != 0) {
            BOO.safeTransfer(to, _pendingBoo);
        }

        IRewarder[] memory _rewarders = rewarders[pid];
        IRewarder _rewarder;
        for (uint256 i = 0; i < _rewarders.length; i++) {
            _rewarder = _rewarders[i];
            if (address(_rewarder) != address(0)) {
                _rewarder.onReward(pid, to, to, _pendingBoo, user.amount);
            }
        }

        lpToken[pid].safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingBoo);
    }

    function withdraw(uint pid, uint amount, address to) external validatePid(pid) {
        _withdraw(pid, amount, to);
    }

    function withdraw(uint pid, uint amount) external validatePid(pid) {
        _withdraw(pid, amount, msg.sender);
    }

    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and BOO rewards.
    function _withdraw(uint pid, uint amount, address to) internal {
        PoolInfo memory pool = _updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        require(user.amount >= amount, "withdraw: not good");

        // Effects
        uint256 _pendingBoo = (user.amount * (pool.accBooPerShare / ACC_BOO_PRECISION)) - user.rewardDebt;

        user.amount -= amount;
        user.rewardDebt = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;

        // Interactions
        if (_pendingBoo != 0) {
            BOO.safeTransfer(to, _pendingBoo);
        }

        IRewarder[] memory _rewarders = rewarders[pid];
        IRewarder _rewarder;
        for (uint256 i = 0; i < _rewarders.length; i++) {
            _rewarder = _rewarders[i];
            if (address(_rewarder) != address(0)) {
                _rewarder.onReward(pid, msg.sender, to, _pendingBoo, user.amount);
            }
        }

        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingBoo);
    }

    /// @notice Batch harvest all rewards from all staked pools
    /// @dev This function has an unbounded gas cost. Take care not to call it from other smart contracts if you don't know what you're doing.
    function harvestAll() external {
        uint256 length = poolInfoAmount;
        uint calc;
        uint pending;
        UserInfo storage user;
        PoolInfo memory pool;
        uint totalPending;
        for (uint256 pid = 0; pid < length; ++pid) {
            user = userInfo[pid][msg.sender];
            if (user.amount > 0) {
                pool = poolInfo[pid];
                _updatePool(pid);

                calc = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;
                pending = calc - user.rewardDebt;
                user.rewardDebt = calc;

                if(pending > 0) {
                    totalPending+=pending;
                }
            }

            IRewarder[] memory _rewarders = rewarders[pid];
            IRewarder _rewarder;
            for (uint j = 0; j < _rewarders.length; j++) {
                _rewarder = _rewarders[j];
                if (address(_rewarder) != address(0)) {
                    _rewarder.onReward(pid, msg.sender, msg.sender, pending, user.amount);
                }
            }
        }
        if (totalPending > 0) {
            BOO.safeTransfer(msg.sender, totalPending);
        }
    }

    /// @notice Batch harvest rewards from specified staked pools
    /// @param pids[] The array of pids of the pools you wish to harvest. See `poolInfo`.
    function harvestMultiple(uint[] memory pids) external {
        uint256 length = pids.length;
        uint calc;
        uint pending;
        UserInfo storage user;
        PoolInfo memory pool;
        uint totalPending;
        uint pid;
        for (uint256 i = 0; i < length; ++i) {
            pid = pids[i];
            user = userInfo[pid][msg.sender];
            if (user.amount > 0) {
                pool = poolInfo[pid];
                _updatePool(pid);

                calc = user.amount * pool.accBooPerShare / ACC_BOO_PRECISION;
                pending = calc - user.rewardDebt;
                user.rewardDebt = calc;

                if(pending > 0) {
                    totalPending+=pending;
                }
            }

            IRewarder[] memory _rewarders = rewarders[pid];
            IRewarder _rewarder;
            for (uint j = 0; j < _rewarders.length; j++) {
                _rewarder = _rewarders[j];
                if (address(_rewarder) != address(0)) {
                    _rewarder.onReward(pid, msg.sender, msg.sender, pending, user.amount);
                }
            }
        }
        if (totalPending > 0) {
            BOO.safeTransfer(msg.sender, totalPending);
        }
    }

    /// @notice Harvests BOO from `MASTER_CHEF` MCV1 and pool `MASTER_PID` to this MCV2 contract.
    function harvestFromMasterChef() public {
        lastV1HarvestTimestamp = block.timestamp;
        MASTER_CHEF.deposit(MASTER_PID, 0);
    }

    /// @notice calls harvestFromMasterChef() if its been more than `V1_HARVEST_QUERY_TIME` since last v1 harvest
    function queryHarvestFromMasterChef() public {
        if(block.timestamp - lastV1HarvestTimestamp > V1_HARVEST_QUERY_TIME)
            harvestFromMasterChef();
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint pid, address to) external validatePid(pid) {
        UserInfo storage user = userInfo[pid][msg.sender];
        uint amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }


    // ADMIN FUNCTIONS

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarders Addresses of the rewarder delegate(s).
    function add(uint64 allocPoint, IERC20 _lpToken, IRewarder[] memory _rewarders, bool update) external onlyOwner {
        checkForDuplicate(_lpToken);
        
        if (update) {
            massUpdateAllPools();
        }

        uint pid = poolInfoAmount;
        uint64 lastRewardTime = uint64(block.timestamp);
        totalAllocPoint = totalAllocPoint + allocPoint;
        lpToken[pid] = _lpToken;
        isLpToken[address(_lpToken)] = true;

        for (uint256 i = 0; i < _rewarders.length; i++) {
            rewarders[pid].push(_rewarders[i]);
        }

        PoolInfo storage poolinfo = poolInfo[pid];
        poolinfo.allocPoint = allocPoint;
        poolinfo.lastRewardTime = lastRewardTime;
        poolinfo.accBooPerShare = 0;

        poolInfoAmount = poolInfoAmount + 1;

        emit LogPoolAddition(poolInfoAmount - 1, allocPoint, _lpToken, _rewarders, update);
    }

    /// @notice Update the given pool's BOO allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarders Addresses of the rewarder delegates.
    /// @param overwrite True if _rewarders should be `set`. Otherwise `_rewarders` is ignored.
    function set(uint _pid, uint64 _allocPoint, IRewarder[] memory _rewarders, bool overwrite, bool update) external validatePid(_pid) onlyOwner {
        
        if (update) {
            massUpdateAllPools();
        }

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (overwrite) {
            delete rewarders[_pid];
            for (uint256 i = 0; i < _rewarders.length; i++) {
                rewarders[_pid].push(_rewarders[i]);
            }
        }
        emit LogSetPool(_pid, _allocPoint, overwrite ? _rewarders : rewarders[_pid], overwrite, update);
    }

    function setV1HarvestQueryTime(uint256 newTime, bool inDays) external onlyOwner {
        V1_HARVEST_QUERY_TIME = newTime * (inDays ? 1 days : 1);
    }


}