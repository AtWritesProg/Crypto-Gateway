// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PaymentGateway} from "../src/PaymentGateway.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {MerchantRegistry} from "../src/MerchantRegistry.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Deployment Script
 * @dev Script to deploy and set up the PaymentGateway system for testing
 */

contract DeployToSepolia is Script {
    // Sepolia Chainlink Price Feeds
    address constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant SEPOLIA_BTC_USD_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address constant SEPOLIA_USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
    
    // Mock token addresses for Sepolia (you'll deploy these too)
    address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC on Sepolia
    
    // Configuration
    uint256 constant PROCESSING_FEE = 250; // 2.5%
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying to Sepolia with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy MerchantRegistry
        console.log("Deploying MerchantRegistry...");
        MerchantRegistry merchantRegistry = new MerchantRegistry();
        console.log("MerchantRegistry deployed at:", address(merchantRegistry));
        
        // 2. Deploy PriceOracle
        console.log("Deploying PriceOracle...");
        PriceOracle priceOracle = new PriceOracle();
        console.log("PriceOracle deployed at:", address(priceOracle));
        
        // 3. Deploy PaymentGateway
        console.log("Deploying PaymentGateway...");
        PaymentGateway paymentGateway = new PaymentGateway(
            address(priceOracle),
            address(merchantRegistry),
            PROCESSING_FEE,
            deployer // Fee recipient
        );
        console.log("PaymentGateway deployed at:", address(paymentGateway));
        
        // 4. Setup Price Feeds
        console.log("Setting up price feeds...");
        
        // Add ETH price feed
        priceOracle.addToken(address(0), SEPOLIA_ETH_USD_FEED, "ETH");
        console.log("Added ETH price feed");
        
        // Add USDC price feed (if available)
        try priceOracle.addToken(SEPOLIA_USDC, SEPOLIA_USDC_USD_FEED, "USDC") {
            console.log("Added USDC price feed");
        } catch {
            console.log("USDC price feed setup failed - will skip");
        }
        
        // 5. Register deployer as first merchant
        console.log("Registering deployer as merchant...");
        merchantRegistry.registerMerchant("Demo Merchant", "demo@example.com");
        console.log("Deployer registered as merchant");
        
        vm.stopBroadcast();
        
        // 6. Print deployment summary
        console.log("\n=== SEPOLIA DEPLOYMENT COMPLETE ===");
        console.log("Network: Sepolia Testnet");
        console.log("Deployer:", deployer);
        console.log("MerchantRegistry:", address(merchantRegistry));
        console.log("PriceOracle:", address(priceOracle));
        console.log("PaymentGateway:", address(paymentGateway));
        console.log("Processing Fee:", PROCESSING_FEE, "basis points (2.5%)");
        console.log("Fee Recipient:", deployer);
        console.log("\nEtherscan URLs:");
        console.log("MerchantRegistry: https://sepolia.etherscan.io/address/", address(merchantRegistry));
        console.log("PriceOracle: https://sepolia.etherscan.io/address/", address(priceOracle));
        console.log("PaymentGateway: https://sepolia.etherscan.io/address/", address(paymentGateway));
        console.log("=====================================");
    }
}