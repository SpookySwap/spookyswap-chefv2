// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/SpookyApprovals.sol";
import "./utils/SelfPermit.sol";
import "./utils/Multicall.sol";

/// @notice boooo! spooooky!! nyahaha! ₍⸍⸌̣ʷ̣̫⸍̣⸌₎
contract LiquidityBrewer is SpookyApprovals, ReentrancyGuard, SelfPermit, Multicall {
    IRouter public Router;
    IMCV2 public MCV2;


    constructor(address router, address mcv2) {
        Router = IRouter(router);
        MCV2 = IMCV2(mcv2);
    }

    //add liquidity and deposit to masterchef v2
    function addLiquidityAndDeposit(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint deadline,
        uint MCV2PID
    ) external nonReentrant {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);
        _approveIfNeeded(tokenA, address(Router));
        _approveIfNeeded(tokenB, address(Router));
        (,, uint liquidity) = Router.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, address(this), deadline);
        _approveIfNeeded(address(MCV2.lpToken(MCV2PID)), address(MCV2));
        MCV2.deposit(MCV2PID, liquidity, msg.sender);
    }

    //add liquidity and deposit to masterchef v2
    function addLiquidityETHAndDeposit(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline,
        uint MCV2PID
    ) external payable nonReentrant {
        IERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired);
        _approveIfNeeded(token, address(Router));
        (,, uint liquidity) = Router.addLiquidityETH{value: msg.value}(token, amountTokenDesired, amountTokenMin, amountETHMin, address(this), deadline);
        _approveIfNeeded(address(MCV2.lpToken(MCV2PID)), address(MCV2));
        MCV2.deposit(MCV2PID, liquidity, msg.sender);
    }
}

interface IRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IMCV2 {
    function deposit(uint pid, uint amount, address to) external;
    function lpToken(uint) external returns (IERC20);
}