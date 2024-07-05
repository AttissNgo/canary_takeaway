// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "test/BaseTest.t.sol";
import {console} from "forge-std/Test.sol";
import {Staker} from "src/Staker.sol";

contract StakerUnitTest is BaseTest {
    
    event Deposit(
        address indexed user, 
        address indexed token, 
        address indexed stToken, 
        uint256 amount
    );

    function test_deposit() public {
        uint256 stakerUsdcBefore = usdc.balanceOf(address(staker));
        uint256 userStUsdcBefore = stUsdc_express.balanceOf(alice);
        uint256 amount = usdc.balanceOf(alice);

        vm.startPrank(alice);
        usdc.approve(address(staker), amount);
        vm.expectEmit(address(staker));
        emit Deposit(alice, address(usdc), address(stUsdc_express), amount);
        staker.deposit(address(usdc), amount, true);
        vm.stopPrank();    

        assertEq(usdc.balanceOf(address(staker)), stakerUsdcBefore + amount);
        assertEq(stUsdc_express.balanceOf(alice), userStUsdcBefore + amount);    
    }

    function test_deposit_revert() public {
        // no value
        vm.expectRevert(Staker.Staker__ZeroInput.selector);
        staker.deposit(address(usdc), 0, true);
        // unapproved token
        vm.expectRevert(Staker.Staker__UnapprovedToken.selector);
        staker.deposit(address(stDai_express), 1, true);
    }

}