// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract StToken is ERC20 {

    address public immutable staker;
    address public immutable underlyingAsset;
    uint256 public immutable noticePeriod;

    error StToken__OnlyStaker();

    modifier onlyStaker() {
        if (msg.sender != staker) revert StToken__OnlyStaker();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _underlyingAsset,
        uint256 _noticePeriod 
    )
        ERC20(string.concat("st", _name), string.concat("st", _symbol))
    {
        staker = msg.sender;
        underlyingAsset = _underlyingAsset;
        noticePeriod = _noticePeriod;
    }

    function mint(address account, uint256 value) external onlyStaker {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyStaker {
        _burn(account, value);
    }


}