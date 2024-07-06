// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "test/BaseTest.t.sol";
import {console} from "forge-std/Test.sol";
import {Staker} from "src/Staker.sol";
import {StToken} from "src/StToken.sol";
import {IStToken} from "src/interfaces/IStToken.sol";

contract StakerUnitTest is BaseTest {
    
     event Deposit(
        address indexed user, 
        address indexed token, 
        address indexed stToken, 
        uint256 amount
    );
    event WithdrawRequested(address indexed account, uint256 amount, uint256 claimId);
    event WithdrawClaimed(address indexed account, address asset, uint256 amount, uint256 claimId);

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
        // paused 
        vm.prank(admin);
        staker.pause();
        vm.prank(alice);
        vm.expectRevert(Staker.Staker__Paused.selector);
        staker.deposit(address(usdc), 1, true);
    }

    function test_requestWithdraw() public userDeposits {
        IStToken stToken = stDai_express;
        uint256 aliceStBalance = stToken.balanceOf(alice);
        uint256 claimTokenId = staker.claimIds();
        uint256 reservedLiquidityBefore = staker.getReservedLiquidity(stToken.underlyingAsset());
        
        vm.warp(block.timestamp + 365 days); // warp one year ahead
        assertEq(stToken.getAccruedYield(alice), 0); // no yield has been recorded

        uint256 expectedYield = stToken.yieldEarnedSinceUpdate(alice);
        assertEq(expectedYield, (aliceStBalance * 5) / 100);

        vm.prank(alice);
        vm.expectEmit(address(staker));
        emit WithdrawRequested(alice, aliceStBalance + expectedYield, claimTokenId);
        uint256 claimId = staker.requestWithdraw(address(stToken), aliceStBalance);

        // total amount reserved in Staker
        assertEq(staker.getReservedLiquidity(stToken.underlyingAsset()), reservedLiquidityBefore + aliceStBalance + expectedYield);
        // st tokens burned
        assertEq(stToken.balanceOf(alice), 0); 
        // claim token minted
        assertEq(staker.claimIds(), claimTokenId + 1); 
        assertEq(claimId, claimTokenId);
        assertEq(staker.ownerOf(claimId), alice);
        assertEq(staker.balanceOf(alice), 1);
        // claim data recorded
        Staker.WithdrawClaim memory claim = staker.getClaim(claimId); 
        assertEq(claim.asset, stToken.underlyingAsset());
        assertEq(claim.amount, aliceStBalance + expectedYield);
        assertEq(claim.noticePeriodExpiry, block.timestamp + stToken.noticePeriod());
    }

    function test_requestWithdraw_yieldOnly() public userDeposits {
        IStToken stToken = stDai_express;
        uint256 aliceStBalance = stToken.balanceOf(alice);
        uint256 claimTokenId = staker.claimIds();
        
        vm.warp(block.timestamp + 365 days); // warp one year ahead
        assertEq(stToken.getAccruedYield(alice), 0); // no yield has been recorded

        uint256 expectedYield = stToken.yieldEarnedSinceUpdate(alice);
        assertEq(expectedYield, (aliceStBalance * 5) / 100);

        vm.prank(alice);
        vm.expectEmit(address(staker));
        emit WithdrawRequested(alice, expectedYield, claimTokenId);
        uint256 claimId = staker.requestWithdraw(address(stToken), 0);
        
        // no st tokens burned
        assertEq(stToken.balanceOf(alice), aliceStBalance); 
        // claim token minted
        assertEq(staker.claimIds(), claimTokenId + 1); 
        assertEq(claimId, claimTokenId);
        assertEq(staker.ownerOf(claimId), alice);
        assertEq(staker.balanceOf(alice), 1);
        // claim data recorded
        Staker.WithdrawClaim memory claim = staker.getClaim(claimId); 
        assertEq(claim.asset, stToken.underlyingAsset());
        assertEq(claim.amount, expectedYield);
        assertEq(claim.noticePeriodExpiry, block.timestamp + stToken.noticePeriod());
    }

    function test_requestWithdraw_revert() public userDeposits {
        StToken unapproved = new StToken("", "", address(0), 1, 8);
        // unapproved token
        vm.prank(alice);
        vm.expectRevert(Staker.Staker__UnapprovedToken.selector);
        staker.requestWithdraw(address(unapproved), 1);
        
        uint256 balance = stDai_express.balanceOf(alice);
        // insufficient token balance
        vm.prank(alice);
        vm.expectRevert();
        staker.requestWithdraw(address(stDai_express), balance + 1);

        // no yield, no amount 
        assertEq(stDai_express.yieldEarnedSinceUpdate(alice), 0);
        assertEq(stDai_express.getAccruedYield(alice), 0);
        vm.prank(alice);
        vm.expectRevert(Staker.Staker__NothingToWithdraw.selector);
        staker.requestWithdraw(address(stDai_express), 0);
    }

    function test_claim() public userDeposits {
        IStToken stToken = stDai_express;
        uint256 aliceStBalance = stToken.balanceOf(alice);
        vm.warp(block.timestamp + 365 days); // warp one year ahead
        uint256 expectedYield = stToken.yieldEarnedSinceUpdate(alice);
        vm.prank(alice);
        uint256 claimId = staker.requestWithdraw(address(stToken), aliceStBalance);
        Staker.WithdrawClaim memory withdrawClaim = staker.getClaim(claimId);

        vm.warp(withdrawClaim.noticePeriodExpiry); // warp to end of notice period  
        uint256 aliceDaiBefore = dai.balanceOf(alice);
        uint256 stakerDaiBefore = dai.balanceOf(address(staker));
        uint256 reservedLiquidityBefore = staker.getReservedLiquidity(stToken.underlyingAsset());
        vm.prank(alice);
        vm.expectEmit(address(staker));
        emit WithdrawClaimed(alice, address(dai), aliceStBalance + expectedYield, claimId);
        staker.claim(claimId);    

        // reserved liquidity updated
        assertEq(staker.getReservedLiquidity(stToken.underlyingAsset()), reservedLiquidityBefore - aliceStBalance - expectedYield);
        // claim token burned
        vm.expectRevert();
        staker.ownerOf(claimId);
        // asset transferred
        assertEq(dai.balanceOf(alice), aliceDaiBefore + aliceStBalance + expectedYield);
        assertEq(dai.balanceOf(address(staker)), stakerDaiBefore - aliceStBalance - expectedYield);
    }

    function test_claim_revert() public userDeposits {
        IStToken stToken = stDai_express;
        uint256 aliceStBalance = stToken.balanceOf(alice);
        vm.warp(block.timestamp + 365 days); // warp one year ahead
        vm.prank(alice);
        uint256 claimId = staker.requestWithdraw(address(stToken), aliceStBalance);
        Staker.WithdrawClaim memory withdrawClaim = staker.getClaim(claimId);

        // not claim owner
        vm.prank(bob);
        vm.expectRevert(Staker.Staker__InvalidClaim.selector);
        staker.claim(claimId);

        // notice period active
        vm.warp(withdrawClaim.noticePeriodExpiry - 1); 
        vm.prank(alice);
        vm.expectRevert(Staker.Staker__NoticePeriodActive.selector);
        staker.claim(claimId);
        // not enough liquidity in contract 
        vm.warp(withdrawClaim.noticePeriodExpiry);
        uint256 transferAmount = dai.balanceOf(address(staker));
        vm.prank(address(staker));
        dai.transfer(bob, transferAmount); 
        vm.prank(alice);
        vm.expectRevert(Staker.Staker__InsufficientLiquidity.selector);
        staker.claim(claimId);
    }
    
    function test_getStake() public userDeposits {
        (uint256 expressAmount, uint256 standardAmount) = staker.getStake(alice, address(usdc));
        assertEq(expressAmount, INITIAL_USER_USDC / 2);
        assertEq(standardAmount, INITIAL_USER_USDC / 2);
    }
    

}