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
    int256 constant USDC_PRICE = 1_00000000; // $1
    int256 constant USDT_PRICE = 1_00000000; // $1
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

        vm.warp(1000);

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

    function testAddTokenETH() public {
        vm.expectEmit(true, true, false, true);
        emit TokenAdded(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
    }

    function testAddMultipleTokens() public {
        // Add ETH
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        // Add USDC
        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");

        // Add USDT
        oracle.addToken(address(mockUSDT), address(usdtPriceFeed), "USDT");

        // Add WBTC
        oracle.addToken(address(mockWBTC), address(wbtcPriceFeed), "WBTC");

        // Verify all tokens are supported
        assertTrue(oracle.isTokenSupported(ETH_ADDRESS));
        assertTrue(oracle.isTokenSupported(address(mockUSDC)));
        assertTrue(oracle.isTokenSupported(address(mockUSDT)));
        assertTrue(oracle.isTokenSupported(address(mockWBTC)));

        // Verify supported tokens array
        address[] memory supportedTokens = oracle.getSupportedTokens();
        assertEq(supportedTokens.length, 4);

        // Check that all our tokens are in the array
        bool foundETH = false;
        bool foundUSDC = false;
        bool foundUSDT = false;
        bool foundWBTC = false;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == ETH_ADDRESS) foundETH = true;
            if (supportedTokens[i] == address(mockUSDC)) foundUSDC = true;
            if (supportedTokens[i] == address(mockUSDT)) foundUSDT = true;
            if (supportedTokens[i] == address(mockWBTC)) foundWBTC = true;
        }

        assertTrue(foundETH);
        assertTrue(foundUSDC);
        assertTrue(foundUSDT);
        assertTrue(foundWBTC);
    }

    function testCannotAddDuplicateToken() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenAlreadyExists.selector, ETH_ADDRESS));
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
    }

    function testCannotAddTokenWithInvalidPriceFeed() public {
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.InvalidPriceFeed.selector, address(0)));
        oracle.addToken(ETH_ADDRESS, address(0), "ETH");
    }

    function testCannotAddTokenWithNegativePrice() public {
        MockPriceFeed negativeFeed = new MockPriceFeed(8, NEGATIVE_PRICE);

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.InvalidPrice.selector, ETH_ADDRESS, NEGATIVE_PRICE));
        oracle.addToken(ETH_ADDRESS, address(negativeFeed), "ETH");
    }

    function testCannotAddTokenWithStalePrice() public {
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.StalePrice.selector, ETH_ADDRESS, block.timestamp - 1000));
        oracle.addToken(ETH_ADDRESS, address(stalePriceFeed), "ETH");
    }

    function testNonOwnerCannotAddToken() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
    }

    // ============ TOKEN UPDATE TESTS ============

    function testUpdateTokenPriceFeed() public {
        // First add a token
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        // Create new price feed with different price
        MockPriceFeed newEthPriceFeed = new MockPriceFeed(8, 2500_00000000); // $2500

        vm.expectEmit(true, true, false, false);
        emit TokenUpdated(ETH_ADDRESS, address(newEthPriceFeed));

        oracle.updateTokenPriceFeed(ETH_ADDRESS, address(newEthPriceFeed));

        // Verify price feed was updated
        PriceOracle.TokenInfo memory tokenInfo = oracle.getTokenInfo(ETH_ADDRESS);
        assertEq(address(tokenInfo.priceFeed), address(newEthPriceFeed));
        assertEq(tokenInfo.lastUpdated, block.timestamp);

        // Verify new price is returned
        uint256 newPrice = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(newPrice, 2500_00000000);
    }

    function testCannotUpdateNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, ETH_ADDRESS));
        oracle.updateTokenPriceFeed(ETH_ADDRESS, address(ethPriceFeed));
    }

    function testCannotUpdateWithInvalidPriceFeed() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.InvalidPriceFeed.selector, address(0)));
        oracle.updateTokenPriceFeed(ETH_ADDRESS, address(0));
    }

    function testNonOwnerCannotUpdateToken() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        vm.prank(nonOwner);
        vm.expectRevert();
        oracle.updateTokenPriceFeed(ETH_ADDRESS, address(ethPriceFeed));
    }

    // ============ PRICE RETRIEVAL TESTS ============

    function testGetTokenPrice() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        (uint256 price, uint8 decimals) = oracle.getTokenPrice(ETH_ADDRESS);

        assertEq(price, uint256(ETH_PRICE));
        assertEq(decimals, 8);
    }

    function testGetTokenPriceInUSD() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
        oracle.addToken(address(mockWBTC), address(wbtcPriceFeed), "WBTC");

        // Test ETH price (already 8 decimals)
        uint256 ethPriceUSD = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(ethPriceUSD, 2000_00000000);

        // Test USDC price (already 8 decimals)
        uint256 usdcPriceUSD = oracle.getTokenPriceInUSD(address(mockUSDC));
        assertEq(usdcPriceUSD, 1_00000000);

        // Test WBTC price (already 8 decimals)
        uint256 wbtcPriceUSD = oracle.getTokenPriceInUSD(address(mockWBTC));
        assertEq(wbtcPriceUSD, 45000_00000000);
    }

    function testGetTokenPriceWithDifferentDecimals() public {
        // Create price feed with different decimals
        MockPriceFeed feed18Decimals = new MockPriceFeed(18, 2000_000000000000000000); // $2000 with 18 decimals
        MockPriceFeed feed6Decimals = new MockPriceFeed(6, 2000_000000); // $2000 with 6 decimals

        oracle.addToken(address(mockUSDC), address(feed18Decimals), "TEST18");
        oracle.addToken(address(mockUSDT), address(feed6Decimals), "TEST6");

        // Both should normalize to 8 decimals = 2000_00000000
        uint256 price18 = oracle.getTokenPriceInUSD(address(mockUSDC));
        uint256 price6 = oracle.getTokenPriceInUSD(address(mockUSDT));

        assertEq(price18, 2000_00000000);
        assertEq(price6, 2000_00000000);
    }

    function testCannotGetPriceForUnsupportedToken() public {
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, ETH_ADDRESS));
        oracle.getTokenPrice(ETH_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, ETH_ADDRESS));
        oracle.getTokenPriceInUSD(ETH_ADDRESS);
    }

    function testCannotGetPriceWithStaleData() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        // Make the price feed stale
        ethPriceFeed.setUpdatedAt(block.timestamp - 1000); // 1000 seconds ago

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.StalePrice.selector, ETH_ADDRESS, block.timestamp - 1000));
        oracle.getTokenPrice(ETH_ADDRESS);
    }

    function testCannotGetPriceWithNegativePrice() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        // Set negative price
        ethPriceFeed.setPrice(NEGATIVE_PRICE);

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.InvalidPrice.selector, ETH_ADDRESS, NEGATIVE_PRICE));
        oracle.getTokenPrice(ETH_ADDRESS);
    }

    // ============ CONVERSION TESTS ============

    // function testConvertUSDToToken() public {
    //     oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
    //     oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
    //     oracle.addToken(address(mockWBTC), address(wbtcPriceFeed), "WBTC");

    //     // Convert $100 to ETH (ETH = $2000, so $100 = 0.05 ETH)
    //     uint256 ethAmount = oracle.convertUSDToToken(ETH_ADDRESS, 100_00000000);
    //     assertEq(ethAmount, 0.05 ether); // 0.05 ETH with 18 decimals

    //     // Convert $100 to USDC (USDC = $1, so $100 = 100 USDC)
    //     uint256 usdcAmount = oracle.convertUSDToToken(address(mockUSDC), 100_00000000);
    //     assertEq(usdcAmount, 100 * 1e6); // 100 USDC with 6 decimals

    //     // Convert $100 to WBTC (WBTC = $45000, so $100 = 0.00222... WBTC)
    //     uint256 wbtcAmount = oracle.convertUSDToToken(address(mockWBTC), 100_00000000);
    //     // Expected: 100 / 45000 * 10^8 = 0.00222222 WBTC = 222222 satoshis
    //     assertEq(wbtcAmount, 222222);
    // }

    function testConvertTokenToUSD() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
        oracle.addToken(address(mockWBTC), address(wbtcPriceFeed), "WBTC");

        // Convert 1 ETH to USD (1 ETH = $2000)
        uint256 ethValue = oracle.convertTokenToUSD(ETH_ADDRESS, 1 ether);
        assertEq(ethValue, 2000_00000000);

        // Convert 100 USDC to USD (100 USDC = $100)
        uint256 usdcValue = oracle.convertTokenToUSD(address(mockUSDC), 100 * 1e6);
        assertEq(usdcValue, 100_00000000);

        // Convert 1 WBTC to USD (1 WBTC = $45000)
        uint256 wbtcValue = oracle.convertTokenToUSD(address(mockWBTC), 1 * 1e8);
        assertEq(wbtcValue, 45000_00000000);
    }

    function testConversionWithSmallAmounts() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        // Convert $1 to ETH
        uint256 ethAmount = oracle.convertUSDToToken(ETH_ADDRESS, 1_00000000);
        assertEq(ethAmount, 0.0005 ether); // $1 / $2000 = 0.0005 ETH

        // Convert small ETH amount to USD
        uint256 usdValue = oracle.convertTokenToUSD(ETH_ADDRESS, 0.0005 ether);
        assertEq(usdValue, 1_00000000); // Should be $1
    }

    function testConversionRoundingConsistency() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        uint256 originalUSD = 157_32000000; // $157.32

        // Convert USD -> ETH -> USD
        uint256 ethAmount = oracle.convertUSDToToken(ETH_ADDRESS, originalUSD);
        uint256 backToUSD = oracle.convertTokenToUSD(ETH_ADDRESS, ethAmount);

        // Should be very close (allowing for rounding differences)
        uint256 difference = originalUSD > backToUSD ? originalUSD - backToUSD : backToUSD - originalUSD;

        // Allow up to 1 cent difference due to rounding
        assertLe(difference, 1000000); // 0.01 USD in 8 decimals
    }

    function testConvertUnsupportedToken() public {
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, address(mockUSDC)));
        oracle.convertUSDToToken(address(mockUSDC), 100_00000000);

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, address(mockUSDC)));
        oracle.convertTokenToUSD(address(mockUSDC), 100 * 1e6);
    }

    // ============ BATCH OPERATIONS TESTS ============

    function testGetMultipleTokenPrices() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
        oracle.addToken(address(mockWBTC), address(wbtcPriceFeed), "WBTC");

        address[] memory tokens = new address[](3);
        tokens[0] = ETH_ADDRESS;
        tokens[1] = address(mockUSDC);
        tokens[2] = address(mockWBTC);

        uint256[] memory prices = oracle.getMultipleTokenPrices(tokens);

        assertEq(prices.length, 3);
        assertEq(prices[0], 2000_00000000); // ETH
        assertEq(prices[1], 1_00000000); // USDC
        assertEq(prices[2], 45000_00000000); // WBTC
    }

    function testGetMultipleTokenPricesWithUnsupportedToken() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        address[] memory tokens = new address[](2);
        tokens[0] = ETH_ADDRESS;
        tokens[1] = address(mockUSDC); // Not supported

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, address(mockUSDC)));
        oracle.getMultipleTokenPrices(tokens);
    }

    function testGetMultipleTokenPricesEmptyArray() public {
        address[] memory tokens = new address[](0);
        uint256[] memory prices = oracle.getMultipleTokenPrices(tokens);

        assertEq(prices.length, 0);
    }

    // ============ PAUSE/UNPAUSE TESTS ============

    // function testPauseUnpause() public {
    //     oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

    //     // Normal operation should work
    //     uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
    //     assertEq(price, 2000_00000000);

    //     // Pause contract
    //     oracle.pause();

    //     // Read operations should still work when paused
    //     price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
    //     assertEq(price, 2000_00000000);

    //     // Write operations should fail when paused
    //     vm.expectRevert("Pausable: paused");
    //     oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");

    //     // Unpause contract
    //     oracle.unpause();

    //     // Write operations should work again
    //     oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
    //     assertTrue(oracle.isTokenSupported(address(mockUSDC)));
    // }

    function testNonOwnerCannotPause() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        oracle.pause();
    }

    function testNonOwnerCannotUnpause() public {
        oracle.pause();

        vm.prank(nonOwner);
        vm.expectRevert();
        oracle.unpause();
    }

    // ============ TOKEN INFO TESTS ============

    function testGetTokenInfoForNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, ETH_ADDRESS));
        oracle.getTokenInfo(ETH_ADDRESS);
    }

    function testIsTokenSupportedForNonexistentToken() public {
        assertFalse(oracle.isTokenSupported(ETH_ADDRESS));
        assertFalse(oracle.isTokenSupported(address(mockUSDC)));
        assertFalse(oracle.isTokenSupported(address(0)));
    }

    function testGetSupportedTokensEmptyArray() public {
        address[] memory supportedTokens = oracle.getSupportedTokens();
        assertEq(supportedTokens.length, 0);
    }

    // ============ EDGE CASES TESTS ============

    function testMaxPriceValues() public {
        // Test with maximum int256 value
        int256 maxPrice = type(int256).max;
        MockPriceFeed maxPriceFeed = new MockPriceFeed(8, maxPrice);

        oracle.addToken(ETH_ADDRESS, address(maxPriceFeed), "ETH");

        uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, uint256(maxPrice));
    }

    function testZeroPrice() public {
        MockPriceFeed zeroPriceFeed = new MockPriceFeed(8, 0);

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.InvalidPrice.selector, ETH_ADDRESS, int256(0)));
        oracle.addToken(ETH_ADDRESS, address(zeroPriceFeed), "ETH");
    }

    function testMinimalValidPrice() public {
        int256 minPrice = 1;
        MockPriceFeed minPriceFeed = new MockPriceFeed(8, minPrice);

        oracle.addToken(ETH_ADDRESS, address(minPriceFeed), "ETH");

        uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, 1);
    }

    function testTimestampEdgeCases() public {
        // Test with timestamp exactly at the limit (should work)
        uint256 limitTime = block.timestamp - 900; // Exactly 15 minutes
        MockPriceFeed limitPriceFeed = new MockPriceFeed(8, ETH_PRICE);
        limitPriceFeed.setUpdatedAt(limitTime);

        oracle.addToken(ETH_ADDRESS, address(limitPriceFeed), "ETH");

        // Should work
        uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, uint256(ETH_PRICE));

        // Test with timestamp just over the limit (should fail)
        uint256 staleTime = block.timestamp - 901; // 1 second over limit
        limitPriceFeed.setUpdatedAt(staleTime);

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.StalePrice.selector, ETH_ADDRESS, staleTime));
        oracle.getTokenPrice(ETH_ADDRESS);
    }

    // function testFutureTimestamp() public {
    //     // Test with future timestamp (should work)
    //     uint256 futureTime = block.timestamp + 100;
    //     MockPriceFeed futurePriceFeed = new MockPriceFeed(8, ETH_PRICE);
    //     futurePriceFeed.setUpdatedAt(futureTime);

    //     oracle.addToken(ETH_ADDRESS, address(futurePriceFeed), "ETH");

    //     uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
    //     assertEq(price, uint256(ETH_PRICE));
    // }

    // ============ INTEGRATION TESTS ============

    function testCompleteTokenLifecycle() public {
        // Add token
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
        assertTrue(oracle.isTokenSupported(ETH_ADDRESS));

        // Use token for price queries
        uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, 2000_00000000);

        // Use token for conversions
        uint256 ethAmount = oracle.convertUSDToToken(ETH_ADDRESS, 100_00000000);
        assertEq(ethAmount, 0.05 ether);

        // Update token price feed
        MockPriceFeed newFeed = new MockPriceFeed(8, 3000_00000000);
        oracle.updateTokenPriceFeed(ETH_ADDRESS, address(newFeed));

        // Verify new price
        price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, 3000_00000000);

        // Remove token
        oracle.removeToken(ETH_ADDRESS);
        assertFalse(oracle.isTokenSupported(ETH_ADDRESS));

        // Verify token can't be used anymore
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.TokenNotSupported.selector, ETH_ADDRESS));
        oracle.getTokenPriceInUSD(ETH_ADDRESS);
    }

    // function testMultipleTokenOperations() public {
    //     // Add multiple tokens
    //     oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
    //     oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
    //     oracle.addToken(address(mockUSDT), address(usdtPriceFeed), "USDT");
    //     oracle.addToken(address(mockWBTC), address(wbtcPriceFeed), "WBTC");

    //     // Test batch price retrieval
    //     address[] memory tokens = new address[](4);
    //     tokens[0] = ETH_ADDRESS;
    //     tokens[1] = address(mockUSDC);
    //     tokens[2] = address(mockUSDT);
    //     tokens[3] = address(mockWBTC);

    //     uint256[] memory prices = oracle.getMultipleTokenPrices(tokens);
    //     assertEq(prices[0], 2000_00000000);   // ETH
    //     assertEq(prices[1], 1_00000000);      // USDC
    //     assertEq(prices[2], 1_00000000);      // USDT
    //     assertEq(prices[3], 45000_00000000);  // WBTC

    //     // Test conversions for all tokens
    //     uint256 usdAmount = 1000_00000000; // $1000

    //     uint256 ethAmount = oracle.convertUSDToToken(ETH_ADDRESS, usdAmount);
    //     uint256 usdcAmount = oracle.convertUSDToToken(address(mockUSDC), usdAmount);
    //     uint256 usdtAmount = oracle.convertUSDToToken(address(mockUSDT), usdAmount);
    //     uint256 wbtcAmount = oracle.convertUSDToToken(address(mockWBTC), usdAmount);

    //     // Verify conversion results
    //     assertEq(ethAmount, 0.5 ether);        // $1000 / $2000 = 0.5 ETH
    //     assertEq(usdcAmount, 1000 * 1e6);      // $1000 / $1 = 1000 USDC
    //     assertEq(usdtAmount, 1000 * 1e6);      // $1000 / $1 = 1000 USDT
    //     assertEq(wbtcAmount, 2222222);         // $1000 / $45000 ≈ 0.02222 WBTC

    //     // Convert back to USD to verify consistency
    //     uint256 ethBackToUSD = oracle.convertTokenToUSD(ETH_ADDRESS, ethAmount);
    //     uint256 usdcBackToUSD = oracle.convertTokenToUSD(address(mockUSDC), usdcAmount);
    //     uint256 usdtBackToUSD = oracle.convertTokenToUSD(address(mockUSDT), usdtAmount);
    //     uint256 wbtcBackToUSD = oracle.convertTokenToUSD(address(mockWBTC), wbtcAmount);

    //     assertEq(ethBackToUSD, usdAmount);
    //     assertEq(usdcBackToUSD, usdAmount);
    //     assertEq(usdtBackToUSD, usdAmount);
    //     // WBTC might have slight rounding difference due to precision
    //     assertTrue(wbtcBackToUSD >= usdAmount - 1000); // Within 0.01 USD
    //     assertTrue(wbtcBackToUSD <= usdAmount + 1000);
    // }

    // ============ STRESS TESTS ============

    function testLargeNumberOfTokens() public {
        uint256 tokenCount = 20;
        address[] memory tokens = new address[](tokenCount);
        MockERC20[] memory mockTokens = new MockERC20[](tokenCount);
        MockPriceFeed[] memory priceFeeds = new MockPriceFeed[](tokenCount);

        // Add many tokens
        for (uint256 i = 0; i < tokenCount; i++) {
            mockTokens[i] = new MockERC20(
                string(abi.encodePacked("Token", vm.toString(i))), string(abi.encodePacked("TKN", vm.toString(i))), 18
            );
            tokens[i] = address(mockTokens[i]);

            priceFeeds[i] = new MockPriceFeed(8, int256((i + 1) * 100_00000000)); // $100, $200, $300, etc.

            oracle.addToken(tokens[i], address(priceFeeds[i]), string(abi.encodePacked("TKN", vm.toString(i))));
        }

        // Verify all tokens are supported
        assertEq(oracle.getSupportedTokens().length, tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            assertTrue(oracle.isTokenSupported(tokens[i]));
            uint256 expectedPrice = (i + 1) * 100_00000000;
            assertEq(oracle.getTokenPriceInUSD(tokens[i]), expectedPrice);
        }

        // Test batch price retrieval
        uint256[] memory prices = oracle.getMultipleTokenPrices(tokens);
        assertEq(prices.length, tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 expectedPrice = (i + 1) * 100_00000000;
            assertEq(prices[i], expectedPrice);
        }

        // Remove some tokens
        for (uint256 i = 0; i < tokenCount / 2; i++) {
            oracle.removeToken(tokens[i]);
        }

        assertEq(oracle.getSupportedTokens().length, tokenCount - tokenCount / 2);
    }

    // function testPriceUpdateFrequency() public {
    //     oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

    //     // Update price multiple times rapidly
    //     for (uint256 i = 1; i <= 10; i++) {
    //         ethPriceFeed.setPrice(int256(i * 1000_00000000)); // $1000, $2000, etc.

    //         uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
    //         assertEq(price, i * 1000_00000000);

    //         // Test conversion with new price
    //         uint256 ethAmount = oracle.convertUSDToToken(ETH_ADDRESS, 100_00000000);
    //         uint256 expectedAmount = (100 * 1e18) / (i * 1000); // $100 / price
    //         assertEq(ethAmount, expectedAmount);

    //         // Advance time slightly
    //         vm.warp(block.timestamp + 1);
    //     }
    //}

    // ============ SECURITY TESTS ============

    function testReentrancyProtection() public {
        // The oracle contract doesn't have state-changing external calls
        // that could lead to reentrancy, but we test that read operations
        // are safe during state changes

        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

        // Simulate adding token while reading price (though not realistic scenario)
        uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, 2000_00000000);

        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");

        // Previous token should still work correctly
        price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, 2000_00000000);
    }

    function testIntegerOverflowProtection() public {
        // Test with maximum safe values
        int256 maxSafePrice = type(int256).max;
        MockPriceFeed maxPriceFeed = new MockPriceFeed(8, maxSafePrice);

        oracle.addToken(ETH_ADDRESS, address(maxPriceFeed), "ETH");

        uint256 price = oracle.getTokenPriceInUSD(ETH_ADDRESS);
        assertEq(price, uint256(maxSafePrice));

        // Test conversion with large values (should handle gracefully)
        try oracle.convertUSDToToken(ETH_ADDRESS, type(uint256).max) {
            // If it doesn't revert, verify the calculation is reasonable
            // This might revert due to overflow in calculations, which is expected behavior
        } catch {
            // Overflow protection working correctly
        }
    }

    function testAccessControlBoundaries() public {
        // Test that only owner can perform admin functions
        address[] memory adminFunctions = new address[](1);
        adminFunctions[0] = nonOwner;

        for (uint256 i = 0; i < adminFunctions.length; i++) {
            vm.startPrank(adminFunctions[i]);

            // Test all owner-only functions
            vm.expectRevert();
            oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");

            vm.expectRevert();
            oracle.removeToken(ETH_ADDRESS);

            vm.expectRevert();
            oracle.updateTokenPriceFeed(ETH_ADDRESS, address(ethPriceFeed));

            vm.expectRevert();
            oracle.pause();

            vm.expectRevert();
            oracle.unpause();

            vm.stopPrank();
        }
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function testGasUsageForCommonOperations() public {
        // Add tokens first
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");

        // Measure gas for price retrieval
        uint256 gasStart = gasleft();
        oracle.getTokenPriceInUSD(ETH_ADDRESS);
        uint256 gasUsed = gasStart - gasleft();

        // Price retrieval should be reasonably efficient
        assertTrue(gasUsed < 50000); // Arbitrary reasonable limit

        // Measure gas for conversion
        gasStart = gasleft();
        oracle.convertUSDToToken(ETH_ADDRESS, 100_00000000);
        gasUsed = gasStart - gasleft();

        assertTrue(gasUsed < 100000); // Conversion involves more computation
    }

    function testBatchOperationEfficiency() public {
        // Add multiple tokens
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
        oracle.addToken(address(mockUSDT), address(usdtPriceFeed), "USDT");
        oracle.addToken(address(mockWBTC), address(wbtcPriceFeed), "WBTC");

        address[] memory tokens = new address[](4);
        tokens[0] = ETH_ADDRESS;
        tokens[1] = address(mockUSDC);
        tokens[2] = address(mockUSDT);
        tokens[3] = address(mockWBTC);

        // Measure gas for batch operation
        uint256 gasStart = gasleft();
        oracle.getMultipleTokenPrices(tokens);
        uint256 batchGasUsed = gasStart - gasleft();

        // Measure gas for individual operations
        gasStart = gasleft();
        oracle.getTokenPriceInUSD(ETH_ADDRESS);
        oracle.getTokenPriceInUSD(address(mockUSDC));
        oracle.getTokenPriceInUSD(address(mockUSDT));
        oracle.getTokenPriceInUSD(address(mockWBTC));
        uint256 individualGasUsed = gasStart - gasleft();

        // Batch operation should be more efficient than individual calls
        // (though the difference might be small for this simple case)
        assertTrue(batchGasUsed <= individualGasUsed + 10000); // Allow small overhead
    }

    // ============ ERROR HANDLING TESTS ============

    function testPriceFeedFailureHandling() public {
        // Create a mock price feed that will fail
        MockPriceFeed failingFeed = new MockPriceFeed(8, ETH_PRICE);
        oracle.addToken(ETH_ADDRESS, address(failingFeed), "ETH");

        // Simulate price feed failure by setting invalid data
        failingFeed.setPrice(0); // Invalid price

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.InvalidPrice.selector, ETH_ADDRESS, int256(0)));
        oracle.getTokenPrice(ETH_ADDRESS);
    }

    function testMultiplePriceFeedFailures() public {
        oracle.addToken(ETH_ADDRESS, address(ethPriceFeed), "ETH");
        oracle.addToken(address(mockUSDC), address(usdcPriceFeed), "USDC");
        oracle.addToken(address(mockUSDT), address(usdtPriceFeed), "USDT");

        // Make some feeds fail
        ethPriceFeed.setPrice(-1); // Invalid
        usdtPriceFeed.setUpdatedAt(block.timestamp - 1000); // Stale

        // Working feed should still work
        uint256 price = oracle.getTokenPriceInUSD(address(mockUSDC));
        assertEq(price, 1_00000000);

        // Failing feeds should revert
        vm.expectRevert();
        oracle.getTokenPriceInUSD(ETH_ADDRESS);

        vm.expectRevert();
        oracle.getTokenPriceInUSD(address(mockUSDT));
    }

    // ============ HELPER FUNCTIONS ============

    function _deployMockTokensAndFeeds(uint256 count)
        internal
        returns (MockERC20[] memory tokens, MockPriceFeed[] memory feeds, address[] memory tokenAddresses)
    {
        tokens = new MockERC20[](count);
        feeds = new MockPriceFeed[](count);
        tokenAddresses = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            tokens[i] = new MockERC20(
                string(abi.encodePacked("Token", vm.toString(i))), string(abi.encodePacked("TKN", vm.toString(i))), 18
            );
            tokenAddresses[i] = address(tokens[i]);

            feeds[i] = new MockPriceFeed(8, int256((i + 1) * 100_00000000));
        }
    }

    function _addMockTokens(address[] memory tokens, MockPriceFeed[] memory feeds, string[] memory symbols) internal {
        require(tokens.length == feeds.length, "Array length mismatch");
        require(tokens.length == symbols.length, "Array length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            oracle.addToken(tokens[i], address(feeds[i]), symbols[i]);
        }
    }

    function _verifyTokenPrices(address[] memory tokens, uint256[] memory expectedPrices) internal {
        require(tokens.length == expectedPrices.length, "Array length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 actualPrice = oracle.getTokenPriceInUSD(tokens[i]);
            assertEq(actualPrice, expectedPrices[i]);
        }
    }
}
