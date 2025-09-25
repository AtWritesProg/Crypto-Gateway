//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPaymentGateway, IPriceOracle, IMerchantRegistry} from "./IPaymentGateway.sol";
import {PaymentUtils, SafeTransfer, MathUtils} from "./PaymentUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PriceOracle} from "./PriceOracle.sol";
/**
 * @title PaymentGateway 
 * @dev Main contract for processing cryptocurrency payments
 */

contract PaymentGateway is IPaymentGateway, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PaymentUtils for *;
    using SafeTransfer for *;
    using MathUtils for uint256;

    // State variables
    IPriceOracle public immutable priceOracle;
    IMerchantRegistry public immutable merchantRegistry;

    // Payment storage
    mapping(bytes32 => Payment) private payments;
    mapping(address => bytes32[]) private merchantPayments;
    mapping(address => uint256) private nonces;
    
    // Fee configuration
    uint256 public processingFee; // in basis points (10000 = 100%)
    address public feeRecipient;
    
    // Payment settings
    uint256 public constant MIN_PAYMENT_DURATION = 5 minutes;
    uint256 public constant MAX_PAYMENT_DURATION = 24 hours;
    uint256 public constant DEFAULT_PAYMENT_DURATION = 30 minutes;

    // ETH address representation
    address private constant ETH_ADDRESS = address(0);
    
    // Events
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);

    // Errors
    error InvalidFeeRecipient();
    error InvalidFee();
    error UnauthorizedMerchant(address merchant);
    error PaymentNotFound(bytes32 paymentId);

    modifier onlyActiveMerchant() {
        if (!merchantRegistry.isMerchantActive(msg.sender)) {
            revert UnauthorizedMerchant(msg.sender);
        }
        _;
    }

    modifier validPayment(bytes32 paymentId) {
        if (payments[paymentId].paymentId == bytes32(0)) {
            revert PaymentNotFound(paymentId);
        }
        _;
    }
    constructor(
        address _priceOracle,
        address _merchantRegistry,
        uint256 _processingFee,
        address _feeRecipient
    ) Ownable(msg.sender){
        if (_priceOracle == address(0) || _merchantRegistry == address(0)) {
            revert InvalidFeeRecipient();
        }
        if (_processingFee > 1000) revert InvalidFee(); // Max 10%
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();

        priceOracle = IPriceOracle(_priceOracle);
        merchantRegistry = IMerchantRegistry(_merchantRegistry);
        processingFee = _processingFee;
        feeRecipient = _feeRecipient;
        
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Create a new payment
     */
    function createPayment(
        address token,
        uint256 amountUSD,
        uint256 duration
    ) external override onlyActiveMerchant whenNotPaused nonReentrant returns (bytes32 paymentId) {
        // Validate inputs
        PaymentUtils.validatePaymentParams(token, amountUSD, duration);

        if (!priceOracle.isTokenSupported(token)) {
            revert PaymentUtils.InvalidToken();
        }
    }
}