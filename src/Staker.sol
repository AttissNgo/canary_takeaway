// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {StToken} from "src/StToken.sol";
import {Create2} from "@openzeppelin/utils/Create2.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IStToken} from "src/interfaces/IStToken.sol";

contract Staker is ERC721 {
    using SafeERC20 for IERC20;

    struct StakeTokens {
        address expressNotice;
        address standardNotice;
    }

    struct WithdrawClaim {
        address asset;
        uint256 amount;
        uint256 noticePeriodExpiry;
    }

    bool public paused;
    address public admin;
    uint256 public claimIds;
    mapping(address => StakeTokens) private stakeTokens;
    mapping(uint256 claimId => WithdrawClaim) private claims;
    mapping(address asset => uint256) private reservedLiquidity; // 'unstaked' liquidity waiting to be claimed
    
    error Staker__OnlyAdmin();
    error Staker__StakeTokensAlreadyExist();
    error Staker__UnapprovedToken();
    error Staker__ZeroInput();
    error Staker__NothingToWithdraw();
    error Staker__InvalidClaim(); 
    error Staker__NoticePeriodActive();
    error Staker__InsufficientLiquidity(); 
    error Staker__Paused();

    event Deposit(
        address indexed account, 
        address indexed token, 
        address indexed stToken, 
        uint256 amount
    );
    event WithdrawRequested(address indexed account, uint256 amount, uint256 claimId);
    event WithdrawClaimed(address indexed account, address asset, uint256 amount, uint256 claimId);
    event Paused();
    event Unpaused();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Staker__OnlyAdmin();
        _;
    }

    constructor(
        string memory _claimTokenName,
        string memory _claimTokenSymbol,
        address[] memory approvedERC20s,
        uint256 expressNotice,
        uint256 standardNotice
    ) 
        ERC721(_claimTokenName, _claimTokenSymbol)
    {
        admin = msg.sender;

        for (uint i; i < approvedERC20s.length; ++i) {
            _approveERC20(ERC20(approvedERC20s[i]), expressNotice, standardNotice);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           Staking & Claims
    //////////////////////////////////////////////////////////////*/  

    function deposit(address token, uint256 amount, bool isExpress) external { 
        if (paused) {
            revert Staker__Paused();
        }
        if (amount == 0) {
            revert Staker__ZeroInput();
        }
        StakeTokens memory sts = stakeTokens[token];
        if (sts.expressNotice == address(0)) {
            revert Staker__UnapprovedToken();
        }

        address stToken = isExpress ? sts.expressNotice : sts.standardNotice;
        IStToken(stToken).mint(msg.sender, amount);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount); 
        emit Deposit(msg.sender, token, stToken, amount);
    }

    function requestWithdraw(address stToken, uint256 amount) external returns (uint256 claimId) {
        IStToken token = IStToken(stToken);
        address asset = token.underlyingAsset();
        (address express, address standard) = getSTAddresses(asset);
        if (stToken != express && stToken != standard) {
            revert Staker__UnapprovedToken();
        }

        uint256 accruedYield = token.getAccruedYield(msg.sender);
        uint256 yieldSinceLastUpdate = token.yieldEarnedSinceUpdate(msg.sender);
        uint256 totalWithdraw = amount + accruedYield + yieldSinceLastUpdate;
        if (totalWithdraw == 0) { 
            revert Staker__NothingToWithdraw();
        }
        
        reservedLiquidity[asset] += totalWithdraw;

        token.burn(msg.sender, amount);

        claimId = claimIds;
        ++claimIds;
        claims[claimId] = WithdrawClaim({
            asset: asset,
            amount: totalWithdraw,
            noticePeriodExpiry: block.timestamp + token.noticePeriod()
        });
        _safeMint(msg.sender, claimId);
        
        emit WithdrawRequested(msg.sender, totalWithdraw, claimId);
    }

    function claim(uint256 claimId) external {
        _requireOwned(claimId);
        if (msg.sender != ownerOf(claimId)) {
            revert Staker__InvalidClaim();
        }
        
        WithdrawClaim memory withdrawClaim = claims[claimId];
        if (block.timestamp < withdrawClaim.noticePeriodExpiry) {
            revert Staker__NoticePeriodActive();
        }

        IERC20 asset = IERC20(withdrawClaim.asset);
        if (withdrawClaim.amount > asset.balanceOf(address(this))) {
            revert Staker__InsufficientLiquidity();
        }

        reservedLiquidity[withdrawClaim.asset] -= withdrawClaim.amount;
        
        _burn(claimId);
        
        emit WithdrawClaimed(msg.sender, withdrawClaim.asset, withdrawClaim.amount, claimId);
        
        asset.safeTransfer(msg.sender, withdrawClaim.amount);
    }

    /*//////////////////////////////////////////////////////////////
                           Admin functions
    //////////////////////////////////////////////////////////////*/
    
    function adminYieldDeposit(address[] calldata tokens, uint256[] calldata amounts) external onlyAdmin {
        // check arrays are the same length 
        // check tokens are approved
        // weekly???
        // transfer tokens from admin 
    }
    
    function pause() external onlyAdmin {
        if (!paused) {
            paused = true;
            emit Paused();
        }
    }

    function unpause() external onlyAdmin {
        if (paused) {
            paused = false;
            emit Unpaused();
        }
    }

    // function approveERC20(ERC20 token, uint256 expressNotice, uint256 standardNotice) external onlyAdmin {
    //     _approveERC20(token, expressNotice, standardNotice);
    // }

    function _approveERC20(ERC20 token, uint256 expressNotice, uint256 standardNotice) private {
        // control notice period inputs more??
        require(standardNotice > expressNotice);

        StakeTokens storage stTokens = stakeTokens[address(token)];
        if (stTokens.expressNotice != address(0)) revert Staker__StakeTokensAlreadyExist();

        stTokens.expressNotice = _deployStToken(token.name(), token.symbol(), address(token), expressNotice, token.decimals());
        stTokens.standardNotice = _deployStToken(token.name(), token.symbol(), address(token), standardNotice, token.decimals());
    }

    function _deployStToken(
        string memory underlyingName,
        string memory underlyingSymbol,
        address underlyingAsset,
        uint256 noticePeriod,
        uint8 underlyingDecimals
    ) 
        private 
        returns (address stToken) 
    {
        bytes memory creationCode = abi.encodePacked(
            type(StToken).creationCode,
            abi.encode(
                underlyingName,
                underlyingSymbol,
                underlyingAsset,
                noticePeriod,
                underlyingDecimals
            )
        );
        stToken = Create2.deploy(0, keccak256(abi.encodePacked(underlyingName)), creationCode);
    }
    
    /*//////////////////////////////////////////////////////////////
                               Read-Only
    //////////////////////////////////////////////////////////////*/

    function getSTAddresses(address underlying) public view returns (address, address) {
        return (stakeTokens[underlying].expressNotice, stakeTokens[underlying].standardNotice);
    }

    function getClaim(uint256 claimId) public view returns (WithdrawClaim memory) {
        _requireOwned(claimId);
        return claims[claimId];
    }

    function getStake(address account, address asset) public view returns (uint256 expressAmount, uint256 standardAmount) {
        (address express, address standard) = getSTAddresses(asset);
        if (express == address(0) || standard == address(0)) {
            revert Staker__UnapprovedToken();
        }
        return (IStToken(express).balanceOf(account), IStToken(standard).balanceOf(account));
    }

    function getReservedLiquidity(address asset) public view returns (uint256) {
        return reservedLiquidity[asset];
    }

}
