// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract SpookyApprovals {
    mapping(address => mapping(address => bool)) public isApproved;

    function _approveIfNeeded(address _token, address _spender) internal {
        if(!isApproved[_token][_spender]) {
            IERC20(_token).approve(address(_spender), 2**256 - 1);
            isApproved[_token][_spender] = true;
        }
    }

}
