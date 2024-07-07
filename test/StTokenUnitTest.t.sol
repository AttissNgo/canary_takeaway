// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "test/BaseTest.t.sol";
import {console} from "forge-std/Test.sol";
import {IStToken} from "src/interfaces/IStToken.sol";
import {Staker} from "src/Staker.sol";

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

        // yield is updated on transfer
        uint256 transferAmount = token.balanceOf(bob);
        vm.prank(bob);
        token.transfer(alice, transferAmount);

        assertEq(token.yieldEarnedSinceUpdate(alice), 0);
        assertEq(token.getAccruedYield(alice), yield); // yield calculated did NOT reflect the new tokens that just entered 
    }

    function test_yieldUpdatedOnChange() public userDeposits() {
        IStToken token = stDai_express;
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        vm.warp(block.timestamp + 365 days); // warp ahead 1 year
        uint256 aliceYieldBefore = token.yieldEarnedSinceUpdate(alice);
        uint256 bobYieldBefore = token.yieldEarnedSinceUpdate(bob);
        assertEq(aliceYieldBefore, (aliceBalanceBefore * 5) / 100);
        assertEq(bobYieldBefore, (bobBalanceBefore * 5) / 100);
        assertEq(token.getAccruedYield(alice), 0); // no transfers so has not been updated
        assertEq(token.getAccruedYield(bob), 0); // no transfers so has not been updated

        vm.prank(alice);
        token.transfer(bob, aliceBalanceBefore / 2); // alice transfers half her st tokens to bob 
        // at this point yield should be updated for both alice & bob
        assertEq(token.getAccruedYield(alice), aliceYieldBefore);
        assertEq(token.getAccruedYield(bob), bobYieldBefore);
        assertEq(token.yieldEarnedSinceUpdate(alice), 0);
        assertEq(token.yieldEarnedSinceUpdate(bob), 0);
        
        vm.warp(block.timestamp + 365 days); // another year passes
        assertEq(token.yieldEarnedSinceUpdate(alice), aliceYieldBefore / 2);
        assertEq(token.yieldEarnedSinceUpdate(bob), bobYieldBefore + (aliceYieldBefore / 2));

        vm.prank(alice);
        token.transfer(bob, aliceBalanceBefore / 2); // alice transfers remaining tokens to bob
        // now yield has been updated for both 
        assertEq(token.getAccruedYield(alice), aliceYieldBefore + (aliceYieldBefore / 2));
        assertEq(token.getAccruedYield(bob), bobYieldBefore + bobYieldBefore + (aliceYieldBefore / 2));
    }

    function test_burnRealizesYield() public userDeposits {
        IStToken token = stUsdc_standard;
        uint256 stBalanceBefore = token.balanceOf(alice);
        vm.warp(block.timestamp + 365 days); // warp ahead 1 year
        uint256 yield = token.yieldEarnedSinceUpdate(alice);
        assertEq(yield, (stBalanceBefore * 5) / 100); // 5% fixed rate

        vm.prank(alice);
        uint256 claimId = staker.requestWithdraw(address(token), stBalanceBefore / 2); // alice requests withdraw for 50% of stake 
        // burn of st tokens should realize ALL yield (represented in claim NFT), and yield accrued should be set back to zero;
        Staker.WithdrawClaim memory withdrawClaim = staker.getClaim(claimId);
        assertEq(withdrawClaim.amount, (stBalanceBefore / 2) + yield);
        assertEq(token.getAccruedYield(alice), 0);

        vm.warp(block.timestamp + 365 days); // warp ahead 1 year
        uint256 newYield = token.yieldEarnedSinceUpdate(alice);
        assertEq(newYield, ((stBalanceBefore * 5) / 100) / 2); // 5% fixed rate earned on remaining 50% of st tokens
    }

    function test_burnRealizesYield_onZeroBurn() public userDeposits {
        // a burn of zero (when user wants to withdraw yield but keep priciple staked) should realize all yield 
        IStToken token = stUsdc_standard;
        uint256 stBalanceBefore = token.balanceOf(alice);
        vm.warp(block.timestamp + 365 days); // warp ahead 1 year
        uint256 yield = token.yieldEarnedSinceUpdate(alice);
        assertEq(yield, (stBalanceBefore * 5) / 100); // 5% fixed rate

        vm.prank(alice);
        uint256 claimId = staker.requestWithdraw(address(token), 0); // alice requests withdraw for YIELD ONLY
        // burn of st tokens should realize ALL yield (represented in claim NFT), and yield accrued should be set back to zero;
        Staker.WithdrawClaim memory withdrawClaim = staker.getClaim(claimId);
        assertEq(withdrawClaim.amount, yield);
        assertEq(token.getAccruedYield(alice), 0);

        vm.warp(block.timestamp + 365 days); // warp ahead 1 year
        uint256 newYield = token.yieldEarnedSinceUpdate(alice);
        assertEq(newYield, (stBalanceBefore * 5) / 100); // 5% fixed rate earned once again
    }

}