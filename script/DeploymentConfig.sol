// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract DeploymentConfig is Script {
    
    struct Config {
        uint256 deployerKey;
        address dai;
        address usdc;
    }

    Config public networkConfig;

    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant DAI_MAINNET_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F; 
    address public constant USDC_MAINNET_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    constructor() {
        if (block.chainid == 31337) {
            networkConfig = getOrCreateAnvilConfig();
        } 
        if (block.chainid == 1) {
            networkConfig = Config({
                deployerKey: DEFAULT_ANVIL_KEY,
                dai: DAI_MAINNET_ADDRESS,
                usdc: USDC_MAINNET_ADDRESS
            });
        }
    }

    function getOrCreateAnvilConfig() public returns (Config memory) {
        if (networkConfig.deployerKey != 0) return networkConfig;

        // deploy mocks
        vm.startBroadcast(DEFAULT_ANVIL_KEY);
        MockERC20 daiMock = new MockERC20("Dai Stablecoin Mock", "DAImock", 18);
        MockERC20 usdcMock = new MockERC20("USD Coin Mock", "USDCmock", 6);
        vm.stopBroadcast();

        return Config({
            deployerKey: DEFAULT_ANVIL_KEY,
            dai: address(daiMock),
            usdc: address(usdcMock)
        });
    }

}