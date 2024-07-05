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

    address public admin; // replace with multi-sig for access control
    uint256 public claimTokenIds;
    mapping(address => StakeTokens) public stakeTokens;
    
    error Staker__OnlyAdmin();
    error Staker__StakeTokensAlreadyExist();
    error Staker__UnapprovedToken();
    error Staker__ZeroInput();

    event Deposit(
        address indexed user, 
        address indexed token, 
        address indexed stToken, 
        uint256 amount
    );

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Staker__OnlyAdmin();
        _;
    }

    modifier noZeroInput(uint256 input) {
        if (input == 0) revert Staker__ZeroInput();
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

    function deposit(address token, uint256 amount, bool isExpress) external noZeroInput(amount) { 
        // if (amount == 0) revert Staker__ZeroInput();
        StakeTokens memory sts = stakeTokens[token];
        if (sts.expressNotice == address(0)) revert Staker__UnapprovedToken();

        address stToken = isExpress ? sts.expressNotice : sts.standardNotice;
        IStToken(stToken).mint(msg.sender, amount);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount); 
        emit Deposit(msg.sender, token, stToken, amount);
    }

    function requestWithdraw(uint256 stTokens, uint256 amount) external noZeroInput(amount) {
        // calculate totalWithdraw = originalAmount + yield (user no longer earns yield) 
        
        // add withdraw to queue -- figure this out
        
        // mint nft 

        // burn st tokens 

    }

    function claim() external {
        // check withdraw queue 
        // update storage
        // burn nft
        // transfer original erc20 to owner
    }

    // function balanceOf(address user) public {
    //     // return all tokens? What is this for???
    // } 

    function adminYieldDeposit(address[] calldata tokens, uint256[] calldata amounts) external onlyAdmin {
        // check arrays are the same length 
        // check tokens are approved
        // weekly???
        // transfer tokens from admin 
    }

    /*//////////////////////////////////////////////////////////////
                           Admin functions
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyAdmin {
        // restricts only new deposits? Or everything???
    }

    function unpause() external onlyAdmin {
        
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
                               Getters
    //////////////////////////////////////////////////////////////*/

    function getSTAddresses(address underlying) public view returns (address, address) {
        return (stakeTokens[underlying].expressNotice, stakeTokens[underlying].standardNotice);
    }

// - deposit
// - requestWithdraw
// - claim
// - balanceOf
// - adminYieldDeposit
// - pause
// - unpause

}
