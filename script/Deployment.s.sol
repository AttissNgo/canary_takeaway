// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DeploymentConfig} from "script/DeploymentConfig.sol";
import {Staker} from "src/Staker.sol";

contract DeploymentScript is Script {
    
    DeploymentConfig config;
    Staker staker;

    address[] approvedErc20s;

    uint256 constant EXPRESS_NOTICE = 7 days;
    uint256 constant STANDARD_NOTICE = 30 days;
    
    // function setUp() public {}

    function run() public returns (Staker, address[] memory) {
        config = new DeploymentConfig();
        (uint256 deployerKey, address dai, address usdc) = config.networkConfig();
        approvedErc20s.push(dai);
        approvedErc20s.push(usdc);

        vm.startBroadcast(deployerKey);
        staker = new Staker("claimToken", "CLAIM", approvedErc20s, EXPRESS_NOTICE, STANDARD_NOTICE);
        vm.stopBroadcast();

        return (staker, approvedErc20s);
    }
}
