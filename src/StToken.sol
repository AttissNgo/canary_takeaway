// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract StToken is ERC20 {

    struct Yield {
        uint256 yieldAccrued;
        uint256 lastUpdate;
    }

    address public immutable staker;
    address public immutable underlyingAsset;
    uint256 public immutable noticePeriod;
    uint8 public immutable underlyingDecimals;

    mapping(address => Yield) private yields;

    uint256 public constant YIELD_RATE = 630_720_000; // 5% annually

    error StToken__OnlyStaker();

    event YieldUpdated(address indexed account, uint256 currentYield);

    modifier onlyStaker() {
        if (msg.sender != staker) revert StToken__OnlyStaker();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _underlyingAsset,
        uint256 _noticePeriod,
        uint8 _underlyingDecimals 
    )
        ERC20(string.concat("st", _name), string.concat("st", _symbol))
    {
        staker = msg.sender;
        underlyingAsset = _underlyingAsset;
        noticePeriod = _noticePeriod;
        underlyingDecimals = _underlyingDecimals;
    }

    function decimals() public view override returns (uint8) {
        return underlyingDecimals;
    }

    /**
     * @notice called by Staker when user stakes underlying ERC20 via `deposit()`
     * @param account user
     * @param value amount of ERC20 tokens staked
     */
    function mint(address account, uint256 value) external onlyStaker {
        _mint(account, value);
    }

    /**
     * @notice called by Staker when user un-stakes underlying ERC20 via `requestWithdraw()`
     * @param account user
     * @param value amount of ERC20 tokens withdrawn (0 when user wants to withdraw only yield earned but leave priciple staked)
     */
    function burn(address account, uint256 value) external onlyStaker {
        _burn(account, value);
    }

    /**
     * @notice updates Yield for all accounts involved in transfer before updating balances via _update()
     * @notice stores yield earned since last update and updates Yield.lastupdate to current block timestamp
     * @notice if burn, Yield.yieldAccrued will be set to zero as all yield will be realized in Claim NFT in Staker
     * @param from sender
     * @param to recipient
     * @param value amount of tokens
     */
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) { // not a burn
            _updateYield(from, false);
        }
        if (to != address(0)) {
            _updateYield(to, false);
        }
        if (to == address(0)) { // if burn, set yield to zero as user MUST withdraw all yield when burning (even 0 amount)
            _updateYield(from, true);
        }
        super._update(from, to, value);
    }

    function _updateYield(address account, bool isBurn) internal {
        Yield storage yield = yields[account];
        if (!isBurn) {
            uint256 yieldEarned = yieldEarnedSinceUpdate(account);
            yield.yieldAccrued += yieldEarned;  
        } else {
            yield.yieldAccrued = 0;
        }
        yield.lastUpdate = block.timestamp;
        emit YieldUpdated(account, yield.yieldAccrued);
        
    }

    /**
     * @notice calculates yield earned for `account` since last update (last mint, transfer or burn)
     */
    function yieldEarnedSinceUpdate(address account) public view returns (uint256) {
        Yield memory yield = yields[account];
        uint256 secondsPassedSinceUpdate = block.timestamp - yield.lastUpdate;
        uint256 balance = balanceOf(account);
        if (secondsPassedSinceUpdate > 0 && balance > 0 && yield.lastUpdate > 0) {
            return (balance * secondsPassedSinceUpdate) / YIELD_RATE;
        } else {
            return 0;
        }
    }

    function getLastUpdate(address account) public view returns (uint256) {
        return yields[account].lastUpdate;
    }

    function getAccruedYield(address account) public view returns (uint256) {
        return yields[account].yieldAccrued;
    }

}