// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PriceOracle.sol";
import "../src/MerchantRegistry.sol";
import "../src/PaymentGateway.sol";
import {MockERC20, MockPriceFeed} from "./MockERC20.t.sol";

/**
 * @title TestHelpers
 * @dev Common test utilities and setup functions for all contract tests
 */
contract TestHelpers is Test {
    // Common test constants
    uint256 public constant PROCESSING_FEE = 250; // 2.5%
    uint256 public constant DEFAULT_PAYMENT_DURATION = 30 minutes;

    // Price constants (8 decimals)
    int256 public constant ETH_PRICE = 2000_00000000; // $2000
    int256 public constant USDC_PRICE = 1_00000000; // $1
    int256 public constant USDT_PRICE = 1_00000000; // $1
    int256 public constant WBTC_PRICE = 45000_00000000; // $45000
    int256 public constant DAI_PRICE = 1_00000000; // $1

    // Test addresses
    address public constant ETH_ADDRESS = address(0);
    address public owner = address(this);
    address public merchant1 = address(0x1);
    address public merchant2 = address(0x2);
    address public merchant3 = address(0x3);
    address public customer1 = address(0x11);
    address public customer2 = address(0x12);
    address public feeRecipient = address(0x99);
    address public nonOwner = address(0x999);

    // Test data
    string public constant BUSINESS_NAME_1 = "Alice's Coffee Shop";
    string public constant BUSINESS_NAME_2 = "Bob's Electronics";
    string public constant BUSINESS_NAME_3 = "Charlie's Books";
    string public constant EMAIL_1 = "alice@coffeeshop.com";
    string public constant EMAIL_2 = "bob@electronics.com";
    string public constant EMAIL_3 = "charlie@books.com";

    // Struct for token configuration
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
        int256 price;
    }

    // Struct for merchant configuration
    struct MerchantConfig {
        address merchantAddress;
        string businessName;
        string email;
    }

    /**
     * @dev Deploy and configure a complete test environment
     */
    function deployTestEnvironment()
        public
        returns (
            PriceOracle oracle,
            MerchantRegistry registry,
            PaymentGateway gateway,
            MockERC20[] memory tokens,
            MockPriceFeed[] memory priceFeeds
        )
    {
        // Deploy main contracts
        registry = new MerchantRegistry();
        oracle = new PriceOracle();
        gateway = new PaymentGateway(address(oracle), address(registry), PROCESSING_FEE, feeRecipient);

        // Deploy test tokens and price feeds
        (tokens, priceFeeds) = deployMockTokensAndFeeds();

        // Setup price feeds in oracle
        oracle.addToken(ETH_ADDRESS, address(priceFeeds[0]), "ETH");
        oracle.addToken(address(tokens[0]), address(priceFeeds[1]), "USDC");
        oracle.addToken(address(tokens[1]), address(priceFeeds[2]), "USDT");
        oracle.addToken(address(tokens[2]), address(priceFeeds[3]), "WBTC");
        oracle.addToken(address(tokens[3]), address(priceFeeds[4]), "DAI");

        // Register test merchants
        registerTestMerchants(registry);

        // Fund test accounts
        fundTestAccounts(tokens);
    }

    /**
     * @dev Deploy mock tokens and price feeds
     */
    function deployMockTokensAndFeeds() public returns (MockERC20[] memory tokens, MockPriceFeed[] memory priceFeeds) {
        TokenConfig[] memory configs = new TokenConfig[](5);
        configs[0] = TokenConfig("Ethereum", "ETH", 18, ETH_PRICE);
        configs[1] = TokenConfig("USD Coin", "USDC", 6, USDC_PRICE);
        configs[2] = TokenConfig("Tether USD", "USDT", 6, USDT_PRICE);
        configs[3] = TokenConfig("Wrapped Bitcoin", "WBTC", 8, WBTC_PRICE);
        configs[4] = TokenConfig("Dai Stablecoin", "DAI", 18, DAI_PRICE);

        tokens = new MockERC20[](4); // ETH is not a token
        priceFeeds = new MockPriceFeed[](5); // Including ETH price feed

        // Deploy ETH price feed
        priceFeeds[0] = new MockPriceFeed(8, ETH_PRICE);

        // Deploy token contracts and price feeds
        for (uint256 i = 1; i < configs.length; i++) {
            tokens[i - 1] = new MockERC20(configs[i].name, configs[i].symbol, configs[i].decimals);
            priceFeeds[i] = new MockPriceFeed(8, configs[i].price);
        }
    }

    /**
     * @dev Register test merchants
     */
    function registerTestMerchants(MerchantRegistry registry) public {
        MerchantConfig[] memory merchants = new MerchantConfig[](3);
        merchants[0] = MerchantConfig(merchant1, BUSINESS_NAME_1, EMAIL_1);
        merchants[1] = MerchantConfig(merchant2, BUSINESS_NAME_2, EMAIL_2);
        merchants[2] = MerchantConfig(merchant3, BUSINESS_NAME_3, EMAIL_3);

        for (uint256 i = 0; i < merchants.length; i++) {
            vm.prank(merchants[i].merchantAddress);
            registry.registerMerchant(merchants[i].businessName, merchants[i].email);
        }
    }

    /**
     * @dev Fund test accounts with ETH and tokens
     */
    function fundTestAccounts(MockERC20[] memory tokens) public {
        address[] memory accounts = new address[](2);
        accounts[0] = customer1;
        accounts[1] = customer2;

        for (uint256 i = 0; i < accounts.length; i++) {
            // Fund with ETH
            vm.deal(accounts[i], 100 ether);

            // Fund with tokens
            for (uint256 j = 0; j < tokens.length; j++) {
                uint256 amount;
                if (tokens[j].decimals() == 6) {
                    amount = 100000 * 1e6; // 100,000 USDC/USDT
                } else if (tokens[j].decimals() == 8) {
                    amount = 10 * 1e8; // 10 WBTC
                } else {
                    amount = 100000 * 1e18; // 100,000 DAI
                }
                tokens[j].mint(accounts[i], amount);
            }
        }
    }

    /**
     * @dev Setup token allowances for gateway contract
     */
    function setupTokenAllowances(MockERC20[] memory tokens, address gateway, address customer) public {
        vm.startPrank(customer);
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].approve(gateway, type(uint256).max);
        }
        vm.stopPrank();
    }

    /**
     * @dev Create a test payment
     */
    function createTestPayment(PaymentGateway gateway, address merchant, address token, uint256 amountUSD)
        public
        returns (bytes32 paymentId)
    {
        vm.prank(merchant);
        return gateway.createPayment(token, amountUSD, DEFAULT_PAYMENT_DURATION);
    }

    /**
     * @dev Process a test payment
     */
    function processTestPayment(PaymentGateway gateway, bytes32 paymentId, address customer, uint256 amount) public {
        IPaymentGateway.Payment memory payment = gateway.getPayment(paymentId);

        if (payment.token == ETH_ADDRESS) {
            vm.prank(customer);
            gateway.processPayment{value: amount}(paymentId);
        } else {
            vm.prank(customer);
            gateway.processTokenPayment(paymentId, amount);
        }
    }

    /**
     * @dev Assert payment status
     */
    function assertPaymentStatus(
        PaymentGateway gateway,
        bytes32 paymentId,
        IPaymentGateway.PaymentStatus expectedStatus
    ) public view {
        IPaymentGateway.PaymentStatus actualStatus = gateway.getPaymentStatus(paymentId);
        assertEq(uint256(actualStatus), uint256(expectedStatus));
    }

    /**
     * @dev Assert token price
     */
    function assertTokenPrice(PriceOracle oracle, address token, uint256 expectedPrice) public view {
        uint256 actualPrice = oracle.getTokenPriceInUSD(token);
        assertEq(actualPrice, expectedPrice);
    }

    /**
     * @dev Assert merchant is active
     */
    function assertMerchantActive(MerchantRegistry registry, address merchant, bool expectedActive) public view {
        bool actualActive = registry.isMerchantActive(merchant);
        assertEq(actualActive, expectedActive);
    }

    /**
     * @dev Fast forward time
     */
    function fastForward(uint256 timeInSeconds) public {
        vm.warp(block.timestamp + timeInSeconds);
    }

    /**
     * @dev Calculate expected token amount from USD
     */
    function calculateExpectedTokenAmount(uint256 usdAmount, uint256 tokenPrice, uint8 tokenDecimals)
        public
        pure
        returns (uint256)
    {
        // usdAmount and tokenPrice both have 8 decimals
        // Result should have tokenDecimals
        return (usdAmount * (10 ** tokenDecimals)) / tokenPrice;
    }

    /**
     * @dev Calculate expected fee amount
     */
    function calculateExpectedFee(uint256 amount, uint256 feePercentage) public pure returns (uint256) {
        return (amount * feePercentage) / 10000;
    }

    /**
     * @dev Get balance of token or ETH
     */
    function getBalance(address token, address account) public view returns (uint256) {
        if (token == ETH_ADDRESS) {
            return account.balance;
        } else {
            return MockERC20(token).balanceOf(account);
        }
    }

    /**
     * @dev Compare two strings for equality
     */
    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /**
     * @dev Generate random address for testing
     */
    function generateRandomAddress(uint256 seed) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
    }

    /**
     * @dev Generate random amount within range
     */
    function generateRandomAmount(uint256 seed, uint256 min, uint256 max) public pure returns (uint256) {
        require(max > min, "Invalid range");
        return min + (uint256(keccak256(abi.encodePacked(seed))) % (max - min));
    }

    /**
     * @dev Create multiple test merchants
     */
    function createMultipleTestMerchants(MerchantRegistry registry, uint256 count)
        public
        returns (address[] memory merchants)
    {
        merchants = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            merchants[i] = generateRandomAddress(i + 1000);

            vm.prank(merchants[i]);
            registry.registerMerchant(
                string(abi.encodePacked("Business ", vm.toString(i))),
                string(abi.encodePacked("email", vm.toString(i), "@test.com"))
            );
        }
    }

    /**
     * @dev Create multiple test payments
     */
    function createMultipleTestPayments(PaymentGateway gateway, address merchant, uint256 count)
        public
        returns (bytes32[] memory paymentIds)
    {
        paymentIds = new bytes32[](count);

        vm.startPrank(merchant);
        for (uint256 i = 0; i < count; i++) {
            uint256 amountUSD = (i + 1) * 50_00000000; // $50, $100, $150, etc.
            paymentIds[i] = gateway.createPayment(ETH_ADDRESS, amountUSD, DEFAULT_PAYMENT_DURATION);
        }
        vm.stopPrank();
    }

    /**
     * @dev Verify contract deployment
     */
    function verifyContractDeployment(PriceOracle oracle, MerchantRegistry registry, PaymentGateway gateway)
        public
        view
    {
        // Check that contracts are deployed
        assertTrue(address(oracle) != address(0));
        assertTrue(address(registry) != address(0));
        assertTrue(address(gateway) != address(0));

        // Check that contracts are properly linked
        assertEq(address(gateway.priceOracle()), address(oracle));
        assertEq(address(gateway.merchantRegistry()), address(registry));

        // Check initial state
        assertEq(gateway.processingFee(), PROCESSING_FEE);
        assertEq(gateway.feeRecipient(), feeRecipient);
    }

    /**
     * @dev Simulate price fluctuations
     */
    function simulatePriceFluctuations(MockPriceFeed[] memory priceFeeds, uint256 volatilityPercent) public {
        for (uint256 i = 0; i < priceFeeds.length; i++) {
            (, int256 currentPrice,,,) = priceFeeds[i].latestRoundData();

            // Generate random price change within volatility range
            uint256 seed = block.timestamp + i;
            bool isIncrease = (seed % 2) == 0;
            uint256 changePercent = (seed % volatilityPercent) + 1;

            int256 priceChange = (currentPrice * int256(changePercent)) / 100;
            int256 newPrice = isIncrease ? currentPrice + priceChange : currentPrice - priceChange;

            // Ensure price doesn't go negative
            if (newPrice <= 0) {
                newPrice = currentPrice / 2;
            }

            priceFeeds[i].setPrice(newPrice);
        }
    }

    /**
     * @dev Create stress test scenario
     */
    function createStressTestScenario(PaymentGateway gateway, address[] memory merchants, uint256 paymentsPerMerchant)
        public
        returns (bytes32[][] memory allPaymentIds)
    {
        allPaymentIds = new bytes32[][](merchants.length);

        for (uint256 i = 0; i < merchants.length; i++) {
            allPaymentIds[i] = createMultipleTestPayments(gateway, merchants[i], paymentsPerMerchant);
        }
    }

    /**
     * @dev Process random payments from stress test
     */
    function processRandomPayments(
        PaymentGateway gateway,
        bytes32[][] memory allPaymentIds,
        uint256 processingRate // percentage of payments to process
    ) public {
        for (uint256 i = 0; i < allPaymentIds.length; i++) {
            for (uint256 j = 0; j < allPaymentIds[i].length; j++) {
                uint256 seed = block.timestamp + i + j;
                if ((seed % 100) < processingRate) {
                    IPaymentGateway.Payment memory payment = gateway.getPayment(allPaymentIds[i][j]);

                    if (payment.token == ETH_ADDRESS) {
                        vm.prank(customer1);
                        try gateway.processPayment{value: payment.amount}(allPaymentIds[i][j]) {
                            // Payment processed successfully
                        } catch {
                            // Payment might be expired or already processed
                        }
                    } else {
                        vm.prank(customer1);
                        try gateway.processTokenPayment(allPaymentIds[i][j], payment.amount) {
                            // Payment processed successfully
                        } catch {
                            // Payment might be expired or already processed
                        }
                    }
                }
            }
        }
    }

    /**
     * @dev Generate test report
     */
    function generateTestReport(PaymentGateway gateway, address[] memory merchants)
        public
        view
        returns (uint256 totalPayments, uint256 completedPayments, uint256 pendingPayments, uint256 expiredPayments)
    {
        for (uint256 i = 0; i < merchants.length; i++) {
            bytes32[] memory merchantPayments = gateway.getMerchantPayments(merchants[i]);
            totalPayments += merchantPayments.length;

            for (uint256 j = 0; j < merchantPayments.length; j++) {
                IPaymentGateway.PaymentStatus status = gateway.getPaymentStatus(merchantPayments[j]);

                if (status == IPaymentGateway.PaymentStatus.Completed) {
                    completedPayments++;
                } else if (status == IPaymentGateway.PaymentStatus.Pending) {
                    pendingPayments++;
                } else if (status == IPaymentGateway.PaymentStatus.Expired) {
                    expiredPayments++;
                }
            }
        }
    }

    /**
     * @dev Setup realistic test environment with multiple tokens and merchants
     */
    function setupRealisticTestEnvironment()
        public
        returns (
            PriceOracle oracle,
            MerchantRegistry registry,
            PaymentGateway gateway,
            MockERC20[] memory tokens,
            MockPriceFeed[] memory priceFeeds,
            address[] memory merchants
        )
    {
        // Deploy main environment
        (oracle, registry, gateway, tokens, priceFeeds) = deployTestEnvironment();

        // Create additional merchants
        merchants = createMultipleTestMerchants(registry, 10);

        // Add the original test merchants
        address[] memory allMerchants = new address[](merchants.length + 3);
        allMerchants[0] = merchant1;
        allMerchants[1] = merchant2;
        allMerchants[2] = merchant3;

        for (uint256 i = 0; i < merchants.length; i++) {
            allMerchants[i + 3] = merchants[i];
        }
        merchants = allMerchants;

        // Setup additional customers
        address[] memory additionalCustomers = new address[](5);
        for (uint256 i = 0; i < additionalCustomers.length; i++) {
            additionalCustomers[i] = generateRandomAddress(2000 + i);
            vm.deal(additionalCustomers[i], 50 ether);

            for (uint256 j = 0; j < tokens.length; j++) {
                uint256 amount;
                if (tokens[j].decimals() == 6) {
                    amount = 50000 * 1e6; // 50,000 USDC/USDT
                } else if (tokens[j].decimals() == 8) {
                    amount = 5 * 1e8; // 5 WBTC
                } else {
                    amount = 50000 * 1e18; // 50,000 DAI
                }
                tokens[j].mint(additionalCustomers[i], amount);
            }

            setupTokenAllowances(tokens, address(gateway), additionalCustomers[i]);
        }
    }

    /**
     * @dev Assert approximate equality for amounts (allowing for small rounding differences)
     */
    function assertApproxEqual(uint256 actual, uint256 expected, uint256 tolerance) public pure {
        if (actual > expected) {
            assertLe(actual - expected, tolerance);
        } else {
            assertLe(expected - actual, tolerance);
        }
    }

    /**
     * @dev Log test results for debugging
     */
    function logTestResults(string memory testName, bool success, uint256 gasUsed) public {
        if (success) {
            emit log_named_string("Correct Test", testName);
        } else {
            emit log_named_string("Wrong Test", testName);
        }
        emit log_named_uint("Gas Used", gasUsed);
    }

    /**
     * @dev Cleanup test environment
     */
    function cleanupTestEnvironment(PaymentGateway gateway, address[] memory merchants) public {
        // Expire all pending payments for cleanup
        for (uint256 i = 0; i < merchants.length; i++) {
            bytes32[] memory merchantPayments = gateway.getMerchantPayments(merchants[i]);

            if (merchantPayments.length > 0) {
                // Fast forward to expire payments
                fastForward(25 hours);

                // Cleanup expired payments
                gateway.cleanupExpiredPayments(merchantPayments);
            }
        }
    }
}
