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

    function mint(address account, uint256 value) external onlyStaker {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyStaker {
        _burn(account, value);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            _updateYield(from);
        }
        if (to != address(0)) {
            _updateYield(to);
        }
        super._update(from, to, value);
    }

    function _updateYield(address account) internal {
        Yield memory yield = yields[account];
        uint256 yieldEarned = yieldEarnedSinceUpdate(account);
        if (yieldEarned > 0 || yield.lastUpdate == 0) { // if there is yield or if this is mint
            yield.yieldAccrued += yieldEarned;
            yield.lastUpdate = block.timestamp;
            yields[account] = yield;    
        }
    }

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