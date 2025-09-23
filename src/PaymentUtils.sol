//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PaymentUtils
 * @dev Library containing utility functions for payment processing
 */

library PaymentUtils {
    using SafeERC20 for IERC20;

    error InvalidAmount();
    error InvalidToken();
    error InvalidDuration();
    error InsufficientBalance();

    /**
     * @dev Generates a unique payment ID
     */
    function generatePaymentId(
        address merchant,
        address token,
        uint256 amount,
        uint256 timestamp,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(merchant, token, amount, timestamp, nonce)
        );
    }

    /** 
     * @dev Validates payment parameters
     */
    function validatePaymentParams(
        address token,
        uint256 amountUSD,
        uint256 duration
    ) internal pure {
        if (token == address(0)) revert InvalidToken();
        if (amountUSD == 0) revert InvalidAmount();
        if (duration == 0) revert InvalidDuration();
    }

    /**
     * @dev Checks if payment is expired
     */
    function isExpired(uint256 expiresAt) internal view returns (bool) {
        return block.timestamp > expiresAt;
    }

    /**
     * @dev Calculate fee amount based on percentage
     */
    function calculateFee(uint256 amount, uint256 feePercentage) internal pure returns (uint256) {
        return (amount * feePercentage);
    }

    /**
     * @dev Safe transfer of ETH
     */
    function safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @dev Safe transfer pf ERC20 tokens
     */
    function safeTransferToken(address token, address from, address to, uint256 amount) internal {
        if (from == address(this)) {
            IERC20(token).safeTransfer(to,amount);
        }else {
            IERC20(token).safeTransferFrom(from,to,amount);
        }
    }

    /**
     * @dev Gets token balance of an address
     */
    function getTokenBalance(address token, address account) internal view returns (uint256) {
        if (token == address(0)) {
            return account.balance;
        }
        return IERC20(token).balanceOf(account);
    }

    /**
     * @dev Validates token allowance for spending
     */
    function validateAllowance(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal view {
        if (token != address(0)) {
            uint256 allowance = IERC20(token).allowance(owner, spender);
            if (allowance < amount) revert InsufficientBalance();
        }
    }
}

/**
 * @title SafeTransfer
 * @dev Library for safe transfer of ETH and ERC20 tokens
 */

library SafeTransfer {
    using SafeERC20 for IERC20;

    error InvalidRecipient();
    error InsufficientBalance();
    error TransferFailed();

    /**
     * @dev Transfer ETH with checks
     */
    function transferETH(address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidRecipient();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @dev Transfer ERC20 tokens with checks
     */
    function transferToken(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (to == address(0)) revert InvalidRecipient();
        if (token == address(0)) revert InvalidRecipient();

        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @dev Transfer tokens from on address to another with checks
     */
    function transferTokenFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (to == address(0) || from == address(0)) revert InvalidRecipient();
        if (token == address(0)) revert InvalidRecipient();
        
        IERC20(token).safeTransferFrom(from, to, amount);
    }
}

/**
 * @title MathUtils
 * @dev Mathematical utility functions with overflow protection
 */
library MathUtils {
    error MathOverflow();
    error DivisionByZero();

    /**
     * @dev Safe Multiplication
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        if (c / a != b) revert MathOverflow();
        return c;
    }

    /**
     * @dev Safe Division
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) revert DivisionByZero();
        return a / b;
    }

    /**
     * @dev Scale Amounr by decimals difference
     */
    function percentage(uint256 amount, uint256 bps) internal pure returns (uint256) {
        return safeMul(amount, bps) / 10000;
    }

    /**
     * @dev Scale amount by decimals difference
     */
    function scaleAmount(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        } else if (fromDecimals < toDecimals) {
            return amount * (10 ** (toDecimals - fromDecimals));
        } else {
            return amount / (10 ** (fromDecimals - toDecimals));
        }
    }
}