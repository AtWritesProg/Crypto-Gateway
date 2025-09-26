// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PaymentGateway} from "../src/PaymentGateway.sol";
/**
 * @title MockERC20
 * @dev Mock ERC20 token for testing
 */

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

/**
 * @title MockPriceFeed
 * @dev Mock Chainlink price feed for testing
 */
contract MockPriceFeed is AggregatorV3Interface {
    uint8 public override decimals;
    string public override description;
    uint256 public override version = 1;
    
    int256 private _price;
    uint80 private _roundId;
    uint256 private _updatedAt;
    
    constructor(uint8 _decimals, int256 _initialPrice) {
        decimals = _decimals;
        _price = _initialPrice;
        _roundId = 1;
        _updatedAt = block.timestamp;
        description = "Mock Price Feed";
    }
    
    function getRoundData(uint80 _roundId_)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId_, _price, _updatedAt, _updatedAt, _roundId_);
    }
    
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
    
    // Helper functions for testing
    function setPrice(int256 newPrice) external {
        _price = newPrice;
        _roundId++;
        _updatedAt = block.timestamp;
    }
    
    function setUpdatedAt(uint256 timestamp) external {
        _updatedAt = timestamp;
    }
}

/**
 * @title MockFailingToken
 * @dev Mock ERC20 token that can be configured to fail transfers
 */
contract MockFailingToken is ERC20 {
    bool public transfersShouldFail = false;
    bool public approvalsShouldFail = false;
    
    constructor() ERC20("Mock Failing Token", "FAIL") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function setTransfersShouldFail(bool shouldFail) external {
        transfersShouldFail = shouldFail;
    }
    
    function setApprovalsShouldFail(bool shouldFail) external {
        approvalsShouldFail = shouldFail;
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(!transfersShouldFail, "MockFailingToken: transfer failed");
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(!transfersShouldFail, "MockFailingToken: transferFrom failed");
        return super.transferFrom(from, to, amount);
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        require(!approvalsShouldFail, "MockFailingToken: approve failed");
        return super.approve(spender, amount);
    }
}

/**
 * @title MockMaliciousContract
 * @dev Contract that can be used to test reentrancy protection
 */
contract MockMaliciousContract {
    PaymentGateway public gateway;
    bytes32 public paymentId;
    bool public shouldReenter = false;
    
    constructor(address _gateway) {
        gateway = PaymentGateway(_gateway);
    }
    
    function setReentrancy(bool _shouldReenter) external {
        shouldReenter = _shouldReenter;
    }
    
    function createAndProcessPayment() external payable {
        // This would be called by a merchant to create a payment
        paymentId = gateway.createPayment(address(0), 100_00000000, 30 minutes);
        
        // Then immediately try to process it
        gateway.processPayment{value: msg.value}(paymentId);
    }
    
    // This function will be called when the contract receives ETH
    receive() external payable {
        if (shouldReenter && paymentId != bytes32(0)) {
            // Try to reenter the processPayment function
            try gateway.processPayment{value: 0}(paymentId) {
                // If successful, the reentrancy guard failed
            } catch {
                // Expected to revert due to reentrancy guard
            }
        }
    }
}

/**
 * @title MockPriceFeedAggregator
 * @dev Mock that simulates multiple price feeds for testing oracle functionality
 */
contract MockPriceFeedAggregator {
    mapping(address => MockPriceFeed) public priceFeeds;
    
    struct TokenConfig {
        address token;
        string symbol;
        uint8 decimals;
        int256 initialPrice;
    }
    
    constructor() {
        // Setup common test tokens
        TokenConfig[] memory configs = new TokenConfig[](4);
        
        configs[0] = TokenConfig({
            token: address(0), // ETH
            symbol: "ETH",
            decimals: 8,
            initialPrice: 2000_00000000 // $2000
        });
        
        configs[1] = TokenConfig({
            token: address(0x1), // Mock USDC
            symbol: "USDC", 
            decimals: 8,
            initialPrice: 1_00000000 // $1
        });
        
        configs[2] = TokenConfig({
            token: address(0x2), // Mock USDT
            symbol: "USDT",
            decimals: 8, 
            initialPrice: 1_00000000 // $1
        });
        
        configs[3] = TokenConfig({
            token: address(0x3), // Mock WBTC
            symbol: "WBTC",
            decimals: 8,
            initialPrice: 45000_00000000 // $45000
        });
        
        for (uint i = 0; i < configs.length; i++) {
            priceFeeds[configs[i].token] = new MockPriceFeed(
                configs[i].decimals,
                configs[i].initialPrice
            );
        }
    }
    
    function getPriceFeed(address token) external view returns (address) {
        return address(priceFeeds[token]);
    }
    
    function updatePrice(address token, int256 newPrice) external {
        require(address(priceFeeds[token]) != address(0), "Price feed not found");
        priceFeeds[token].setPrice(newPrice);
    }
    
    function getPrice(address token) external view returns (int256) {
        require(address(priceFeeds[token]) != address(0), "Price feed not found");
        (, int256 price, , , ) = priceFeeds[token].latestRoundData();
        return price;
    }
}