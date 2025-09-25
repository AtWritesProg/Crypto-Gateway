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
    // error PaymentExpired(bytes32 paymentId); // Removed duplicate declaration
    error InvalidFeeRecipient();
    error InvalidFee();
    error UnauthorizedMerchant(address merchant);
    error PaymentNotFound(bytes32 paymentId);
    error PaymentAlreadyProcessed(bytes32 paymentId);
    error PaymentHasExpired(bytes32 paymentId);
    error InvalidPaymentAmount(uint256 expected, uint256 provided);
    error InsufficientPayment(uint256 required, uint256 provided);
    

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
        
        //Ensure duration is within the bounds
        if(duration < MIN_PAYMENT_DURATION || duration > MAX_PAYMENT_DURATION) {
            duration = DEFAULT_PAYMENT_DURATION;
        }

        //Generate unique payment ID
        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender]++;
        paymentId = PaymentUtils.generatePaymentId(
            msg.sender,
            token,
            amountUSD,
            block.timestamp,
            nonce
        );

        // Convert USD to token amount
        uint256 tokenAmount = priceOracle.convertUSDToToken(token, amountUSD);

        payments[paymentId] = Payment({
            paymentId: paymentId,
            merchant: msg.sender,
            customer: address(0),
            token: token,
            amount: tokenAmount,
            amountUSD:amountUSD,
            timestamp: uint64(block.timestamp),
            expiresAt: uint64(block.timestamp + duration),
            status: PaymentStatus.Pending
        });

        merchantPayments[msg.sender].push(paymentId);

        emit PaymentCreated(paymentId,msg.sender,token,tokenAmount,amountUSD,uint64(block.timestamp));

        return paymentId;
    }

    /**
     * @dev Process ETH payment
     */
    function processPayment(bytes32 paymentId) external payable override validPayment(paymentId) whenNotPaused nonReentrant {
        Payment storage payment = payments[paymentId];

        // Validate payment state
        _validatePaymentForProcessing(payment);

        if(payment.token != ETH_ADDRESS) {
            revert InvalidPaymentAmount(0, msg.value);
        }

        uint256 requiredAmount = payment.amount;
        if(msg.value < requiredAmount) {
            revert InsufficientPayment(requiredAmount, msg.value);
        }

        //Calculate Fees
        uint256 feeAmount = payment.amount.percentage(processingFee);
        uint256 merchantAmount = payment.amount - feeAmount;

        // Update payment status
        payment.status = PaymentStatus.Completed;
        payment.customer = msg.sender;

        // Transfer funds
        if (feeAmount > 0) {
            SafeTransfer.transferETH(feeRecipient, feeAmount);
        }
        SafeTransfer.transferETH(payment.merchant, merchantAmount);

        // Refund excess payment
        if (msg.value > requiredAmount) {
            SafeTransfer.transferETH(msg.sender, msg.value - requiredAmount);
        }

        emit PaymentCompleted(paymentId, msg.sender, msg.value);
    }

    /**
     * @dev Process ERC20 token payment
     */
    function processTokenPayment(bytes32 paymentId, uint256 amount) external override validPayment(paymentId) whenNotPaused nonReentrant {
        Payment storage payment = payments[paymentId];

        _validatePaymentForProcessing(payment);

        if(payment.token == ETH_ADDRESS) {
            revert InvalidPaymentAmount(0, amount);
        }

        uint256 requiredAmount = payment.amount;
        if(amount < requiredAmount) {
            revert InsufficientPayment(requiredAmount, amount);
        }

        // Calculate fees
        uint256 feeAmount = amount.percentage(processingFee);
        uint256 merchantAmount = amount - feeAmount;

        // Update payment status
        payment.status = PaymentStatus.Completed;
        payment.customer = msg.sender;

        // Transfer tokens
        IERC20 token = IERC20(payment.token);
        
        if (feeAmount > 0) {
            token.safeTransferFrom(msg.sender, feeRecipient, feeAmount);
        }
        token.safeTransferFrom(msg.sender, payment.merchant, merchantAmount);

        emit PaymentCompleted(paymentId, msg.sender, amount);
    }

    /**
     * @dev Refund a payment
     */

    function refundPayment(bytes32 paymentId) external override validPayment(paymentId) whenNotPaused nonReentrant {
        Payment storage payment = payments[paymentId];

        //Only merchants can refund active payments, anyone can refund expired payments
        if (payment.status != PaymentStatus.Completed) {
            revert PaymentNotFound(paymentId);
        }

        if (msg.sender != payment.merchant && !PaymentUtils.isExpired(payment.expiresAt)) {
            revert UnauthorizedMerchant(msg.sender);
        }        

        // Update payment status
        payment.status = PaymentStatus.Refunded;

        // Process refund
        if (payment.token == ETH_ADDRESS) {
            SafeTransfer.transferETH(payment.customer, payment.amount);
        } else {
            IERC20(payment.token).safeTransfer(payment.customer, payment.amount);
        }

        emit PaymentRefunded(paymentId, payment.customer, payment.amount);
    }

    /**
     * @dev Get payment details
     */
    function getPayment(bytes32 paymentId) external view override returns (Payment memory) {
        if (payments[paymentId].paymentId == bytes32(0)) {
            revert PaymentNotFound(paymentId);
        }
        return payments[paymentId];
    }

    /**
     * @dev Get all payments IDs for a merchant
     */
    function getMerchantPayments(address merchant) external view override returns (bytes32[] memory) {
        return merchantPayments[merchant];
    }

    /**
     * @dev Get Payment Status
     */
    function getPaymentStatus(bytes32 paymentId) external view returns (PaymentStatus) {
        Payment memory payment = payments[paymentId];
        
        if (payment.paymentId == bytes32(0)) {
            revert PaymentNotFound(paymentId);
        }

        // Update status if expired
        if (payment.status == PaymentStatus.Pending && PaymentUtils.isExpired(payment.expiresAt)) {
            return PaymentStatus.Expired;
        }

        return payment.status;
    }

    function isPaymentValid(bytes32 paymentId) external view override returns (bool) {
        Payment memory payment = payments[paymentId];
        
        if (payment.paymentId == bytes32(0)) return false;
        if (payment.status != PaymentStatus.Pending) return false;
        if (PaymentUtils.isExpired(payment.expiresAt)) return false;
        
        return true;
    }

    /**
     * @dev Clean up expired payments
     */
    function cleanupExpiredPayments(bytes32[] memory paymentIds) external {
        for (uint256 i = 0; i < paymentIds.length; i++) {
            Payment storage payment = payments[paymentIds[i]];
            
            if (payment.paymentId != bytes32(0) && 
                payment.status == PaymentStatus.Pending && 
                PaymentUtils.isExpired(payment.expiresAt)) {
                
                payment.status = PaymentStatus.Expired;
                emit PaymentExpired(paymentIds[i]);
            }
        }
    }

    // Administrative functions

    /**
     * @dev Update processing fee (only Owner)
     */
    function updateProcessingFee(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert InvalidFee();

        uint256 oldFee = processingFee;
        processingFee = newFee;

        emit FeeUpdated(oldFee, newFee);
    }

    /**
     * @dev Update fee recipient (only owner)
     */
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidFeeRecipient();
        
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @dev Pause contract (emergency)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency withdrawal of stuck funds (only owner)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == ETH_ADDRESS) {
            SafeTransfer.transferETH(owner(), amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    //Internal Function
    function _validatePaymentForProcessing(Payment memory payment) internal view {
        if (payment.status != PaymentStatus.Pending) {
            revert PaymentAlreadyProcessed(payment.paymentId);
        }

        if(PaymentUtils.isExpired(payment.expiresAt)) {
            revert PaymentHasExpired(payment.paymentId);
        }
    }

    /**
     * @dev Get current nonce for merchant
     */
    function getMerchantNonce(address merchant) external view returns (uint256) {
        return nonces[merchant];
    }

    /**
     * @dev Get total payments count for merchant
     */
    function getMerchantPaymentCount(address merchant) external view returns (uint256) {
        return merchantPayments[merchant].length;
    }

    /**
     * @dev Get paginated merchant payments
     */
    function getMerchantPaymentsPaginated(
        address merchant,
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory paginatedPayments) {
        bytes32[] memory allPayments = merchantPayments[merchant];
        
        if (offset >= allPayments.length) {
            return new bytes32[](0);
        }
        
        uint256 end = offset + limit;
        if (end > allPayments.length) {
            end = allPayments.length;
        }
        
        paginatedPayments = new bytes32[](end - offset);
        
        for (uint256 i = offset; i < end; i++) {
            paginatedPayments[i - offset] = allPayments[i];
        }
    }
}