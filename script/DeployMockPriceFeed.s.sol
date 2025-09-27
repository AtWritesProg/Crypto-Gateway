// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {MockPriceFeed} from "../test/MockERC20.t.sol";

/**
 * @title DeployMockPriceFeed
 * @dev Deploy mock price feed and add to existing oracle
 */
contract DeployMockPriceFeed is Script {
    // Your deployed PriceOracle address
    address constant PRICE_ORACLE = 0x9A6bD99eAc3E7e043e73f92df5572f4D3A14424C;
    
    // Current ETH price (around $4000)
    int256 constant ETH_PRICE = 400000000000; // $4000 with 8 decimals
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying MockPriceFeed with account:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock price feed
        console.log("Deploying MockPriceFeed...");
        MockPriceFeed mockPriceFeed = new MockPriceFeed(8, ETH_PRICE);
        console.log("MockPriceFeed deployed at:", address(mockPriceFeed));
        
        // Add to existing oracle
        console.log("Adding ETH price feed to oracle...");
        PriceOracle oracle = PriceOracle(PRICE_ORACLE);
        oracle.addToken(address(0), address(mockPriceFeed), "ETH");
        console.log("ETH price feed added successfully");
        
        // Verify it works
        uint256 ethPrice = oracle.getTokenPriceInUSD(address(0));
        console.log("ETH price from oracle:", ethPrice);
        
        vm.stopBroadcast();
        
        console.log("\n=== MOCK PRICE FEED DEPLOYMENT COMPLETE ===");
        console.log("MockPriceFeed:", address(mockPriceFeed));
        console.log("ETH Price: $", ethPrice / 1e8);
        console.log("PriceOracle:", PRICE_ORACLE);
        console.log("PaymentGateway can now create ETH payments!");
        console.log("===============================================");
    }
}