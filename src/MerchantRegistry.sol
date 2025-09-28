//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IMerchantRegistry} from "./IPaymentGateway.sol";

/**
 * @title Merchant Registry
 * @dev Contract for managing merchant registrations and details
 */
contract MerchantRegistry is IMerchantRegistry, Ownable, Pausable {
    //Merchant Storage
    mapping(address => Merchant) private merchants;
    address[] private merchantList;

    // Stats
    uint256 public totalMerchants;
    uint256 public activeMerchants;

    // Configuration
    uint256 public constant MAX_BUSINESS_NAME_LENGTH = 100;
    uint256 public constant MAX_EMAIL_LENGTH = 100;

    modifier onlyRegisteredMerchant() {
        require(merchants[msg.sender].merchantAddress != address(0), "Not Registered");
        _;
    }

    modifier onlyActiveMerchant() {
        require(merchants[msg.sender].isActive, "Merchant not active");
        _;
    }

    error MerchantAlreadyExists(address merchant);
    error InvalidBusinessName();
    error InvalidEmail();
    error MerchantNotFound(address merchant);

    constructor() Ownable(msg.sender) {
        _transferOwnership(msg.sender);
    }

    function registerMerchant(string memory businessName, string memory email) external override whenNotPaused {
        address merchantAddr = msg.sender;

        if (merchants[merchantAddr].merchantAddress != address(0)) {
            revert MerchantAlreadyExists(merchantAddr);
        }

        _validateMerchantData(businessName, email);

        merchants[merchantAddr] = Merchant({
            merchantAddress: merchantAddr,
            businessName: businessName,
            email: email,
            isActive: true,
            registeredAt: block.timestamp,
            totalPayments: 0,
            totalVolume: 0
        });

        merchantList.push(merchantAddr);
        totalMerchants++;
        activeMerchants++;

        emit MerchantRegistered(merchantAddr, businessName);
    }

    /**
     * @dev Update merchant information
     */
    function updateMerchant(string memory businessName, string memory email)
        external
        override
        onlyRegisteredMerchant
        whenNotPaused
    {
        _validateMerchantData(businessName, email);

        Merchant storage merchant = merchants[msg.sender];
        merchant.businessName = businessName;
        merchant.email = email;

        emit MerchantUpdated(msg.sender, businessName);
    }

    /**
     * @dev Sets the activity to deactivate the merchant
     */
    function deactivateMerchant(address merchant) external override onlyOwner {
        if (merchants[merchant].merchantAddress == address(0)) {
            revert MerchantNotFound(merchant);
        }

        if (merchants[merchant].isActive) {
            merchants[merchant].isActive = false;
            activeMerchants--;

            emit MerchantDeactivated(merchant);
        }
    }

    /**
     * @dev Reactivates the merchant
     */
    function reactivateMerchant(address merchant) external onlyOwner {
        if (merchants[merchant].merchantAddress == address(0)) revert MerchantNotFound(merchant);

        if (!merchants[merchant].isActive) {
            merchants[merchant].isActive = true;
            activeMerchants++;

            emit MerchantRegistered(merchant, merchants[merchant].businessName);
        }
    }

    /**
     * @dev Checks if the merchant is active
     */
    function isMerchantActive(address merchant) external view override returns (bool) {
        return merchants[merchant].isActive;
    }

    /**
     * @dev Deactivate my account- Self
     */
    function deactivateMyAccount() external onlyRegisteredMerchant {
        if (merchants[msg.sender].isActive) {
            merchants[msg.sender].isActive = false;
            activeMerchants--;

            emit MerchantDeactivated(msg.sender);
        }
    }

    /**
     * @dev Update merchant stats
     */
    function updateMerchantStats(address merchant, uint256 paymentAmount) external {
        // This should be called only by authorized contracts (PaymentGateway)
        // In a real implementation, you'd have role-based access control

        if (merchants[merchant].merchantAddress == address(0)) {
            revert MerchantNotFound(merchant);
        }

        Merchant storage merchantData = merchants[merchant];
        merchantData.totalPayments++;
        merchantData.totalVolume += paymentAmount;
    }

    /**
     * @dev Get Merchant
     */
    function getMerchant(address merchant) external view override returns (Merchant memory) {
        if (merchants[merchant].merchantAddress == address(0)) {
            revert MerchantNotFound(merchant);
        }
        return merchants[merchant];
    }

    /**
     * @dev Get all Merchants
     */
    function getMerchants(uint256 offset, uint256 limit) external view returns (Merchant[] memory) {
        if (offset >= merchantList.length) {
            return new Merchant[](0);
        }

        uint256 end = offset + limit;
        if (end > merchantList.length) {
            end = merchantList.length;
        }

        Merchant[] memory result = new Merchant[](end - offset);

        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = merchants[merchantList[i]];
        }

        return result;
    }

    /**
     * @dev Get active merchants only
     */
    function getActiveMerchants(uint256 offset, uint256 limit) external view returns (Merchant[] memory) {
        // Count active merchants first
        uint256 activeCount = 0;
        for (uint256 i = 0; i < merchantList.length; i++) {
            if (merchants[merchantList[i]].isActive) {
                activeCount++;
            }
        }

        if (offset >= activeCount) {
            return new Merchant[](0);
        }

        uint256 end = offset + limit;
        if (end > activeCount) {
            end = activeCount;
        }

        Merchant[] memory result = new Merchant[](end - offset);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < merchantList.length && resultIndex < (end - offset); i++) {
            if (merchants[merchantList[i]].isActive) {
                if (currentIndex >= offset) {
                    result[resultIndex] = merchants[merchantList[i]];
                    resultIndex++;
                }
                currentIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Search merchants by business name
     */
    function searchMerchantsByName(string calldata searchTerm) external view returns (Merchant[] memory) {
        // Simple search implementation
        // In production, you might want to use a more sophisticated search mechanism

        bytes memory searchBytes = bytes(searchTerm);
        if (searchBytes.length == 0) {
            return new Merchant[](0);
        }

        // First pass: count matches
        uint256 matchCount = 0;
        for (uint256 i = 0; i < merchantList.length; i++) {
            if (_containsString(merchants[merchantList[i]].businessName, searchTerm)) {
                matchCount++;
            }
        }

        // Second pass: collect matches
        Merchant[] memory result = new Merchant[](matchCount);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < merchantList.length; i++) {
            if (_containsString(merchants[merchantList[i]].businessName, searchTerm)) {
                result[resultIndex] = merchants[merchantList[i]];
                resultIndex++;
            }
        }

        return result;
    }

    /**
     * @dev Get merchant statistics
     */
    function getMerchantStats(address merchant)
        external
        view
        returns (uint256 totalPayments, uint256 totalVolume, uint256 registeredAt)
    {
        if (merchants[merchant].merchantAddress == address(0)) {
            revert MerchantNotFound(merchant);
        }

        Merchant memory merchantData = merchants[merchant];
        return (merchantData.totalPayments, merchantData.totalVolume, merchantData.registeredAt);
    }

    /**
     * @dev Get registry statistics
     */
    function getRegistryStats() external view returns (uint256 total, uint256 active, uint256 inactive) {
        return (totalMerchants, activeMerchants, totalMerchants - activeMerchants);
    }

    /**
     * @dev Emergency pause (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    //Internal Functions

    /**
     * @dev Validate merchant data
     */
    function _validateMerchantData(string memory businessName, string memory email) internal pure {
        if (bytes(businessName).length == 0 || bytes(businessName).length > MAX_BUSINESS_NAME_LENGTH) {
            revert InvalidBusinessName();
        }

        if (bytes(email).length == 0 || bytes(email).length > MAX_EMAIL_LENGTH) {
            revert InvalidEmail();
        }

        // Basic email validation (contains @ symbol)
        if (!_containsString(email, "@")) {
            revert InvalidEmail();
        }
    }

    function _containsString(string memory source, string memory search) internal pure returns (bool) {
        bytes memory sourceBytes = bytes(source);
        bytes memory searchBytes = bytes(search);

        if (searchBytes.length > sourceBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= sourceBytes.length - searchBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < searchBytes.length; j++) {
                if (sourceBytes[i + j] != searchBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }
}
