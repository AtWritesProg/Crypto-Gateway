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
    function updateMerchant(string memory businessName, string memory email) external override onlyRegisteredMerchant whenNotPaused {}

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
}