// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DeploymentScript} from "script/Deployment.s.sol";
import {Staker} from "src/Staker.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract BaseTest is Test {
    
    DeploymentScript deploymentScript;
    Staker public staker;
    MockERC20 public dai;
    MockERC20 public usdc;

    function setUp() public {
        deploymentScript = new DeploymentScript();
        address[] memory erc20s;
        (staker, erc20s) = deploymentScript.run();
        dai = MockERC20(erc20s[0]);
        usdc = MockERC20(erc20s[1]);
    }

    function test_smokeTest() public {
        console.log(staker.name());
        (address stExpDai, address stStdDai) = staker.getSTAddresses(address(dai));
        console.log(stExpDai);
    }
}
