// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.13;

import "./utils/SpookyApprovals.sol";
import "./utils/SelfPermit.sol";
import "./utils/Multicall.sol";
import "./router/UniswapV2Router02.sol";

/// @notice boooo! spooooky!! nyahaha! ₍⸍⸌̣ʷ̣̫⸍̣⸌₎
contract LiquidityBrewer is SpookyApprovals, UniswapV2Router02, SelfPermit, Multicall {
    IMCV2 public MCV2;

    constructor(address _factory, address _WETH, address mcv2) UniswapV2Router02(_factory, _WETH) {
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
        address to,
        uint deadline,
        uint MCV2PID
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);

        _approveIfNeeded(pair, address(MCV2));
        MCV2.deposit(MCV2PID, liquidity, to);
    }

    //add liquidity and deposit to masterchef v2
    function addLiquidityETHAndDeposit(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint MCV2PID
    ) external payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IUniswapV2Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);

        _approveIfNeeded(pair, address(MCV2));
        MCV2.deposit(MCV2PID, liquidity, to);
    }

    //deposit to masterchef v2
    function deposit(address token, uint pid, uint amount, address to) external {
        if(token == address(0))
            token = address(MCV2.lpToken(pid));
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        _approveIfNeeded(token, address(MCV2));
        MCV2.deposit(pid, amount, to);
    }

    //in case more than max_uint wei of a token are transferred in the lifetime
    function reApprove(uint pid) external {
        IERC20(address(MCV2.lpToken(pid))).approve(address(MCV2), 2**256 - 1);
    }
}

interface IMCV2 {
    function deposit(uint pid, uint amount, address to) external;
    function lpToken(uint) external returns (IERC20);
}