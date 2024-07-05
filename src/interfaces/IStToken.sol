// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

interface IStToken is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function noticePeriod() external view returns (uint256);
    function underlyingAsset() external view returns (address);
    function YIELD_RATE() external view returns(uint256);
    function getAccruedYield(address account) external view returns (uint256);
    function yieldEarnedSinceUpdate(address account) external view returns (uint256);
    function getLastUpdate(address account) external view returns (uint256);

    // staker only
    function mint(address account, uint256 value) external;
    function burn(address account, uint256 value) external;
}