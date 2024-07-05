// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DeploymentScript} from "script/Deployment.s.sol";
import {Staker} from "src/Staker.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IStToken} from "src/interfaces/IStToken.sol";

contract BaseTest is Test {
    
    DeploymentScript deploymentScript;
    Staker public staker;
    MockERC20 public dai;
    MockERC20 public usdc;

    IStToken public stDai_express;
    IStToken public stDai_standard;
    IStToken public stUsdc_express;
    IStToken public stUsdc_standard;

    uint256 public constant INITIAL_USER_DAI = 100e18;
    uint256 public constant INITIAL_USER_USDC = 100e6;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public admin;
    address[] public users = [alice, bob];

    modifier userDeposits() {
        for (uint i; i < users.length; ++i) {
            uint256 daiAmount = dai.balanceOf(users[i]) / 2;
            uint256 usdcAmount = usdc.balanceOf(users[i]) / 2;
            vm.startPrank(users[i]);
            dai.approve(address(staker), daiAmount * 2);
            usdc.approve(address(staker), usdcAmount * 2);
            staker.deposit(address(dai), daiAmount, true);
            staker.deposit(address(dai), daiAmount, false);
            staker.deposit(address(usdc), usdcAmount, true);
            staker.deposit(address(usdc), usdcAmount, false);
            vm.stopPrank();
        }
        _;
    }

    function setUp() public {
        deploymentScript = new DeploymentScript();
        address[] memory erc20s;

        (staker, erc20s) = deploymentScript.run();
        
        dai = MockERC20(erc20s[0]);
        usdc = MockERC20(erc20s[1]);
        _setStTokens();

        admin = staker.admin();

        _supplyERC20();
    }

    function _supplyERC20() internal {
        for (uint i; i < users.length; ++i) {
            dai.mint(users[i], INITIAL_USER_DAI);
            usdc.mint(users[i], INITIAL_USER_USDC);
        }
    }

    function _setStTokens() internal {
        (address stDaiExp, address stDaiStd) = staker.getSTAddresses(address(dai));
        stDai_express = IStToken(stDaiExp);
        stDai_standard = IStToken(stDaiStd);
        (address stUsdcExp, address stUsdcStd) = staker.getSTAddresses(address(usdc));
        stUsdc_express = IStToken(stUsdcExp);
        stUsdc_standard = IStToken(stUsdcStd);
    }


    // function test_smokeTest() public {
    //     console.log(staker.name());
    //     (address stExpDai, address stStdDai) = staker.getSTAddresses(address(dai));
    //     console.log(stExpDai);
        
    // }
}
