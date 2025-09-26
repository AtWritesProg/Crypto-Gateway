//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockERC20, MockPriceFeed} from "./MockERC20.t.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {IPriceOracle} from "../src/IPaymentGateway.sol";

/**
 * @title Price Oracle Tests
 * @dev Tests for the PriceOracle contract
 */

contract TestPriceOracle is Test {
    PriceOracle public oracle;

    MockERC20 public mockUSDC;
    MockERC20 public mockUSDT;
    MockERC20 public mockWBTC;

    MockPriceFeed public ethPriceFeed;
    MockPriceFeed public usdcPriceFeed;
    MockPriceFeed public usdtPriceFeed;
    MockPriceFeed public wbtcPriceFeed;
    MockPriceFeed public stalePriceFeed;

    // Test accounts
    address public owner;
    address public nonOwner = address(0x999);
    
    // Test price data (with 8 decimals as per Chainlink standard)
    int256 constant ETH_PRICE = 2000_00000000; // $2000
    int256 constant USDC_PRICE = 1_00000000;   // $1
    int256 constant USDT_PRICE = 1_00000000;   // $1  
    int256 constant WBTC_PRICE = 45000_00000000; // $45000
    int256 constant NEGATIVE_PRICE = -100_00000000; // Invalid negative price
    
    // ETH address representation
    address constant ETH_ADDRESS = address(0);
    
    // Events for testing
    event TokenAdded(address indexed token, address indexed priceFeed, string symbol);
    event TokenUpdated(address indexed token, address indexed priceFeed);
    event TokenRemoved(address indexed token);

    function setUp() public {
        owner = address(this);
        oracle = new PriceOracle();
        
        // Deploy mock tokens
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
        mockUSDT = new MockERC20("Mock USDT", "USDT", 6);
        mockWBTC = new MockERC20("Mock WBTC", "WBTC", 8);
        
        // Deploy mock price feeds
        ethPriceFeed = new MockPriceFeed(8, ETH_PRICE);
        usdcPriceFeed = new MockPriceFeed(8, USDC_PRICE);
        usdtPriceFeed = new MockPriceFeed(8, USDT_PRICE);
        wbtcPriceFeed = new MockPriceFeed(8, WBTC_PRICE);
        
        // Create stale price feed (old timestamp)
        stalePriceFeed = new MockPriceFeed(8, ETH_PRICE);
        stalePriceFeed.setUpdatedAt(block.timestamp - 1000); // 1000 seconds ago
    }

}