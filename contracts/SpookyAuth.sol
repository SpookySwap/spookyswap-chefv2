// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

abstract contract SpookyAuth {
    // set of addresses that can perform certain functions
    mapping(address => bool) public isAuth;
    address[] public authorized;

    modifier onlyAuth() {
        require(isAuth[msg.sender], "SpookySwap: FORBIDDEN");
        _;
    }

    event AddAuth(address indexed by, address indexed to);
    event RevokeAuth(address indexed by, address indexed to);

    constructor() {
        isAuth[msg.sender] = true;
        authorized.push(msg.sender);
        emit AddAuth(address(this), msg.sender);
    }

    function addAuth(address _auth) external onlyAuth {
        isAuth[_auth] = true;
        authorized.push(_auth);
        emit AddAuth(msg.sender, _auth);
    }

    function revokeAuth(address _auth) external onlyAuth {
        isAuth[_auth] = false;
        emit RevokeAuth(msg.sender, _auth);
    }
}
