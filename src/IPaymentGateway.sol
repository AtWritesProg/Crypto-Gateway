//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @title IPaymentGateway
 * @dev Interface for the main payment gateway contract
 */
interface IPaymentGateway {
    struct Payment {
        bytes32 paymentId;
        address merchant;
        address customer;
        address token;
        uint256 amount;
        uint256 amountUSD;
        uint64 timestamp;
        uint64 expiresAt;
        PaymentStatus status;
    }

    enum PaymentStatus {
        Pending,
        Completed,
        Failed,
        Expired,
        Refunded
    }

    event PaymentCreated(
        bytes32 indexed paymentId,
        address indexed merchant,
        address indexed token,
        uint256 amount,
        uint256 amountUSD,
        uint64 expiresAt
    );

    event PaymentCompleted(bytes32 indexed paymentId, address indexed customer, uint256 actualAmount);

    event PaymentFailed(bytes32 indexed paymentId, string reason);

    event PaymentExpired(bytes32 indexed paymentId);

    event PaymentRefunded(bytes32 indexed paymentId, address indexed customer, uint256 amount);

    function createPayment(address token, uint256 amountUSD, uint256 duration) external returns (bytes32 paymentId);

    function processPayment(bytes32 paymentId) external payable;

    function processTokenPayment(bytes32 paymentId, uint256 amount) external;

    function refundPayment(bytes32 paymentId) external;

    function getPayment(bytes32 paymentId) external view returns (Payment memory);

    function getMerchantPayments(address merchant) external view returns (bytes32[] memory);

    function isPaymentValid(bytes32 paymentId) external view returns (bool);
}

/**
 * @title IPriceOracle
 * @dev Interface for price oracle contract
 */
interface IPriceOracle {
    function getTokenPrice(address token) external view returns (uint256 price, uint8 decimals);

    function getTokenPriceInUSD(address token) external view returns (uint256);

    function convertUSDToToken(address token, uint256 usdAmount) external view returns (uint256);

    function convertTokenToUSD(address token, uint256 tokenAmount) external view returns (uint256);

    function isTokenSupported(address token) external view returns (bool);
}

/**
 * @title IMerchantRegistry
 * @dev Interface for merchant management
 */
interface IMerchantRegistry {
    struct Merchant {
        address merchantAddress;
        string businessName;
        string email;
        bool isActive;
        uint256 registeredAt;
        uint256 totalPayments;
        uint256 totalVolume;
    }

    event MerchantRegistered(address indexed merchant, string businessName);
    event MerchantUpdated(address indexed merchant, string businessName);
    event MerchantDeactivated(address indexed merchant);

    function registerMerchant(string memory businessName, string memory email) external;

    function updateMerchant(string memory businessName, string memory email) external;

    function deactivateMerchant(address merchant) external;

    function isMerchantActive(address merchant) external view returns (bool);

    function getMerchant(address merchant) external view returns (Merchant memory);
}
