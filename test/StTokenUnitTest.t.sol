// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "test/BaseTest.t.sol";
import {console} from "forge-std/Test.sol";
import {IStToken} from "src/interfaces/IStToken.sol";

contract StTokenUnitTest is BaseTest {
    
    function test_mint() public {
        uint256 daiAmount = dai.balanceOf(alice);
        uint256 stDaiBefore = stDai_express.balanceOf(alice);
        uint256 lastUpdate = stDai_express.getLastUpdate(alice);
        assertEq(lastUpdate, 0); 
        
        vm.startPrank(alice);
        dai.approve(address(staker), daiAmount);
        staker.deposit(address(dai), daiAmount, true);
        vm.stopPrank();

        assertEq(stDai_express.balanceOf(alice), stDaiBefore + daiAmount); // stTokens minted
        assertEq(stDai_express.getLastUpdate(alice), block.timestamp); // last update written
    }

    function test_yieldEarned() public userDeposits {
        IStToken token = stUsdc_standard;
        assertEq(token.balanceOf(alice), INITIAL_USER_USDC / 2);
        assertEq(token.yieldEarnedSinceUpdate(alice), 0); // zero yield earned since was minted this block

        vm.warp(block.timestamp + 365 days); // warp ahead 1 year

        uint256 yield = token.yieldEarnedSinceUpdate(alice);
        assertEq(yield, (token.balanceOf(alice) * 5) / 100); // 5% fixed rate

        // is the yield realized on any kind of change?? Let's test a transfer
        uint256 transferAmount = token.balanceOf(bob);
        vm.prank(bob);
        token.transfer(alice, transferAmount);

        assertEq(token.yieldEarnedSinceUpdate(alice), 0);
        assertEq(token.getAccruedYield(alice), yield); // yield calculated did NOT reflect the new tokens that just entered 
    }

}