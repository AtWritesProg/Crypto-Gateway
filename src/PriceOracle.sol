// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPriceOracle} from "./IPaymentGateway.sol";
import {MathUtils} from "./PaymentUtils.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract PriceOracle is IPriceOracle, Ownable, Pausable, ReentrancyGuard{
    using MathUtils for uint256;

    struct TokenInfo{
        AggregatorV3Interface priceFeed;
        uint8 decimals;
        bool isActive;
        uint256 lastUpdated;
        string symbol;
    }

    mapping(address => TokenInfo) private tokenFeeds;

    // Array of supported token Addresses
    address[] private supportedTokens;

    // ETH address representation (0x0 for native ETH)
    address private constant ETH_ADDRESS = address(0);
    
    // Maximum price age in seconds (15 minutes)
    uint256 private constant MAX_PRICE_AGE = 900;
    
    // Price deviation threshold (5%)
    uint256 private constant PRICE_DEVIATION_THRESHOLD = 500; // 5% in basis points

    event TokenAdded(address indexed token, address indexed priceFeed, string symbol);
    event TokenUpdated(address indexed token, address indexed priceFeed);
    event TokenRemoved(address indexed token);
    event PriceUpdated(address indexed token, uint256 price, uint256 timestamp);

    //error
    error TokenAlreadyExists(address token);
    error InvalidPriceFeed(address priceFeed);
    error InvalidPrice(address token, int256 price);
    error StalePrice(address token, uint256 updatedAt);
    error TokenNotSupported(address token);

    constructor() Ownable(msg.sender){
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Add a new supported token with its chainlink price feed
     */
    function addToken(address token, address priceFeed, string memory symbol) external onlyOwner {
        if (tokenFeeds[token].isActive) revert TokenAlreadyExists(token);
        if (priceFeed == address(0)) revert InvalidPriceFeed(priceFeed);

        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);

        // Validate the price feed by getting latest price
        try feed.latestRoundData() returns (
            uint80,
            int256 price,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            if (price <= 0) revert InvalidPrice(token, price);
            if(block.timestamp - updatedAt > MAX_PRICE_AGE) {
                revert StalePrice(token, updatedAt);
            }
        } catch {
            revert InvalidPriceFeed(priceFeed);
        }

        tokenFeeds[token] = TokenInfo({
            priceFeed: feed,
            decimals: feed.decimals(),
            isActive: true,
            lastUpdated: block.timestamp,
            symbol: symbol
        });

        supportedTokens.push(token);

        emit TokenAdded(token, priceFeed, symbol);
    }

    /**
     * @dev Update price feed for existing token
     */

    function updateTokenPriceFeed(address token, address newPriceFeed) external onlyOwner {
        if (!tokenFeeds[token].isActive) revert TokenNotSupported(token);
        if (newPriceFeed == address(0)) revert InvalidPriceFeed(newPriceFeed);
        
        AggregatorV3Interface feed = AggregatorV3Interface(newPriceFeed);

        try feed.latestRoundData() returns (uint80, int256 price, uint256, uint256, uint80) {
            if (price <= 0) revert InvalidPrice(token, price);
            if (newPriceFeed == address(0)) revert InvalidPriceFeed(newPriceFeed);
        } catch {
            revert InvalidPriceFeed(newPriceFeed);
        }

        tokenFeeds[token].priceFeed = feed;
        tokenFeeds[token].decimals = feed.decimals();
        tokenFeeds[token].lastUpdated = block.timestamp;

        emit TokenUpdated(token, newPriceFeed);
    }

    /**
     * @dev Remove a supported token
     */
    function removeToken(address token) external onlyOwner {
        if (!tokenFeeds[token].isActive) revert TokenNotSupported(token);

        tokenFeeds[token].isActive = false;

        // Remove from supported tokens array
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }

        emit TokenRemoved(token);
    }

    /**
     * @dev Get latest price and decimals for a token
     */
    function getTokenPrice(address token) external view override returns (uint256 price, uint8 decimals) {
        if (!tokenFeeds[token].isActive) revert TokenNotSupported(token);

        TokenInfo memory tokenInfo = tokenFeeds[token];

        (, int256 latestPrice, ,uint256 updatedAt,) = tokenInfo.priceFeed.latestRoundData();

        if(latestPrice <= 0) revert InvalidPrice(token, latestPrice);
        if (block.timestamp - updatedAt > MAX_PRICE_AGE) {
            revert StalePrice(token, updatedAt);
        }

        return (uint256(latestPrice), tokenInfo.decimals);
    }

    /**
     * @dev Get token price in USD (normalized to 8 decimals)
     */
    function getTokenPriceInUSD(address token) external view override returns (uint256) {
        (uint256 price, uint8 decimals) = this.getTokenPrice(token);

        if (decimals > 8) {
            return price / (10 ** (decimals - 8));
        } else if (decimals < 8) {
            return price * (10 ** (8 - decimals));
        }
        return price;
    }
    /**
     * @dev Convert USD to Token 
     */

    function convertUSDToToken(address token, uint256 usdAmount) external view override returns (uint256) {
        uint256 tokenPriceInUSD = this.getTokenPriceInUSD(token);

        // usdAmount is in 8 decimals, convert to token decimals
        uint8 tokenDecimals = _getTokenDecimals(token);
        uint256 scaledUsdAmount = usdAmount.scaleAmount(8, tokenDecimals);

        return scaledUsdAmount.safeDiv(tokenPriceInUSD) * (10 ** 8);
    }

    /**
     * @dev Convert Token to USD
     */

    function convertTokenToUSD(address token, uint256 tokenAmount) external view override returns (uint256) {
        uint256 tokenPriceUSD = this.getTokenPriceInUSD(token);
        uint8 tokenDecimals = _getTokenDecimals(token);

        // Scale token amount to 8 decimals and multiply by price
        uint256 scaledTokenAmount = tokenAmount.scaleAmount(tokenDecimals, 8);
        return scaledTokenAmount.safeMul(tokenPriceUSD) / (10 ** 8);
    }

    /**
     * @dev Check if token is supported
     */
    function isTokenSupported(address token) external view override returns (bool) {
        return tokenFeeds[token].isActive;
    }

    /**
     * @dev Get all supported tokens
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @dev Get token information
     */
    function getTokenInfo(address token) external view returns (TokenInfo memory) {
        if (!tokenFeeds[token].isActive) revert TokenNotSupported(token);
        return tokenFeeds[token];
    }

    /**
     * @dev Get multiple token prices in batch
     */
    function getMultipleTokenPrices(address[] calldata tokens) 
        external 
        view 
        returns (uint256[] memory prices) 
    {
        prices = new uint256[](tokens.length);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            prices[i] = this.getTokenPriceInUSD(tokens[i]);
        }
    }

    /**
     * @dev Emergency pause functionality
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause functionality
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // Internal Functions
    function _getTokenDecimals(address token) internal view returns (uint8) {
        if (token == ETH_ADDRESS) {
            return 18;
        }

        // For ERC20 tokens, try to get decimals
        try IERC20Metadata(token).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            return 18; // Default to 18 if decimals() call fails
        }
    }
}
