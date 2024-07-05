// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {

    uint8 public immutable DECIMALS;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) 
        ERC20(_name, _symbol)
    {
        DECIMALS = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}