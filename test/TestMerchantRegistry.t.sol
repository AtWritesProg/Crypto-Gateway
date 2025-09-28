// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {MerchantRegistry} from "../src/MerchantRegistry.sol";
import {Test} from "forge-std/Test.sol";
import {IMerchantRegistry} from "../src/IPaymentGateway.sol";

/**
 * @title MerchantRegistry Test
 * @dev Comprehensive tests for the MerchantRegistry contract
 */
contract TestMerchantRegistry is Test {
    MerchantRegistry public registry;

    //Test accounts
    address public owner;
    address public merchant1 = address(0x1);
    address public merchant2 = address(0x2);
    address public merchant3 = address(0x3);
    address public nonMerchant = address(0x999);

    //Test data
    string constant BUSINESS_NAME_1 = "Barcelona's Coffee Shop";
    string constant EMAIL_1 = "barca@coffeeshop.com";

    string constant BUSINESS_NAME_2 = "Arteta's Bus";
    string constant EMAIL_2 = "itzafuggindisgrace@bus.com";

    string constant BUSINESS_NAME_3 = "Miami's Mafia";
    string constant EMAIL_3 = "IMissBarca@gmail.com";

    // Events for testing
    event MerchantRegistered(address indexed merchant, string businessName);
    event MerchantUpdated(address indexed merchant, string businessName);
    event MerchantDeactivated(address indexed merchant);

    function setUp() public {
        owner = address(this);
        registry = new MerchantRegistry();
    }

    // Registration Tests

    function testRegisterMerchant() public {
        vm.prank(merchant1);

        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit MerchantRegistered(merchant1, BUSINESS_NAME_1);

        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        // Verify merchant data
        IMerchantRegistry.Merchant memory merchant = registry.getMerchant(merchant1);

        assertEq(merchant.merchantAddress, merchant1);
        assertEq(merchant.businessName, BUSINESS_NAME_1);
        assertEq(merchant.email, EMAIL_1);
        assertTrue(merchant.isActive);
        assertEq(merchant.totalPayments, 0);
        assertEq(merchant.totalVolume, 0);
        assertTrue(merchant.registeredAt > 0);
        assertTrue(merchant.registeredAt <= block.timestamp);

        // Verify registry stats
        assertTrue(registry.isMerchantActive(merchant1));
        assertEq(registry.totalMerchants(), 1);
        assertEq(registry.activeMerchants(), 1);
    }

    function testRegisterMultipleMerchants() public {
        //Register first merchant
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        //Register second merchant
        vm.prank(merchant2);
        registry.registerMerchant(BUSINESS_NAME_2, EMAIL_2);

        //Register third merchant
        vm.prank(merchant3);
        registry.registerMerchant(BUSINESS_NAME_3, EMAIL_3);

        // Verify all merchants are registered
        assertTrue(registry.isMerchantActive(merchant1));
        assertTrue(registry.isMerchantActive(merchant2));
        assertTrue(registry.isMerchantActive(merchant3));

        // Verify registry stats
        assertEq(registry.totalMerchants(), 3);
        assertEq(registry.activeMerchants(), 3);

        // Verify individual merchant data
        IMerchantRegistry.Merchant memory m1 = registry.getMerchant(merchant1);
        IMerchantRegistry.Merchant memory m2 = registry.getMerchant(merchant2);
        IMerchantRegistry.Merchant memory m3 = registry.getMerchant(merchant3);

        assertEq(m1.businessName, BUSINESS_NAME_1);
        assertEq(m2.businessName, BUSINESS_NAME_2);
        assertEq(m3.businessName, BUSINESS_NAME_3);
    }

    function testCannotRegisterDuplicateMerchant() public {
        //Register merchant first time
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        vm.prank(merchant1);
        vm.expectRevert(abi.encodeWithSelector(MerchantRegistry.MerchantAlreadyExists.selector, merchant1));
        registry.registerMerchant("New Business Name", "new@email.com");
    }

    function testCannotRegisterWithEmptyName() public {
        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidBusinessName.selector);
        registry.registerMerchant("", EMAIL_1);
    }

    function testCannotRegisterWithEmptyBusinessName() public {
        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidBusinessName.selector);
        registry.registerMerchant("", EMAIL_1);
    }

    function testCannotRegisterWithTooLongBusinessName() public {
        // Create a business name that exceeds the 100 character limit
        string memory longName =
            "This is a very long business name that exceeds the maximum allowed length of 100 characters for testing purposes and should be rejected";

        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidBusinessName.selector);
        registry.registerMerchant(longName, EMAIL_1);
    }

    function testCannotRegisterWithEmptyEmail() public {
        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidEmail.selector);
        registry.registerMerchant(BUSINESS_NAME_1, "");
    }

    function testCannotRegisterWithTooLongEmail() public {
        // Create email that exceeds 100 character limit
        string memory longEmail =
            "okthisisaverylongemailaddressthatexceedsthemaximumallowedlengthof100charactersfortestingpurposes@example.com";

        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidEmail.selector);
        registry.registerMerchant(BUSINESS_NAME_1, longEmail);
    }

    function testCannotRegisterWithInvalidEmail() public {
        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidEmail.selector);
        registry.registerMerchant(BUSINESS_NAME_1, "invalid-email-without-at-symbol");
    }

    function testCannotRegisterWhenPaused() public {
        // Pause the contract
        registry.pause();

        vm.prank(merchant1);
        vm.expectRevert();
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);
    }

    // ============= Update Tests =============

    function testUpdateMerchant() public {
        // First register the merchant
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        //Update merchant info
        string memory newBusinessName = "Alice's Premium Coffee";
        string memory newEmail = "premium@alice.com";

        vm.prank(merchant1);
        vm.expectEmit(true, false, false, true);
        emit MerchantUpdated(merchant1, newBusinessName);

        registry.updateMerchant(newBusinessName, newEmail);

        // Verify updated data
        IMerchantRegistry.Merchant memory merchant = registry.getMerchant(merchant1);
        assertEq(merchant.businessName, newBusinessName);
        assertEq(merchant.email, newEmail);

        // Verify other data unchanged
        assertEq(merchant.merchantAddress, merchant1);
        assertTrue(merchant.isActive);
        assertEq(merchant.totalPayments, 0);
        assertEq(merchant.totalVolume, 0);
    }

    function testCannotUpdateUnregisteredMerchant() public {
        vm.prank(nonMerchant);
        vm.expectRevert();
        registry.updateMerchant("New Name", "new@email.com");
    }

    function testCannotUpdateWithInvalidData() public {
        // Register merchant first
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        // Try to update with empty business name
        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidBusinessName.selector);
        registry.updateMerchant("", "new@email.com");

        // Try to update with invalid email
        vm.prank(merchant1);
        vm.expectRevert(MerchantRegistry.InvalidEmail.selector);
        registry.updateMerchant("New Name", "invalid-email");
    }

    function testCannotUpdateWhenPaused() public {
        // Register merchant first
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        // Pause the contract
        registry.pause();

        vm.prank(merchant1);
        vm.expectRevert();
        registry.updateMerchant("New Name", "new@email.com");
    }

    //================== DEACTIVATION TESTS =================

    function testOwnerCanDeactivateMerchant() public {
        // Register merchant
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        // Verify merchant is active
        assertTrue(registry.isMerchantActive(merchant1));
        assertEq(registry.activeMerchants(), 1);

        // Deactivate by owner
        vm.expectEmit(true, false, false, false);
        emit MerchantDeactivated(merchant1);

        registry.deactivateMerchant(merchant1);

        // Verify merchant is deactivated
        assertFalse(registry.isMerchantActive(merchant1));
        assertEq(registry.activeMerchants(), 0);
        assertEq(registry.totalMerchants(), 1); // Total should remain same

        // Verify merchant data still exists but inactive
        IMerchantRegistry.Merchant memory merchant = registry.getMerchant(merchant1);
        assertFalse(merchant.isActive);
        assertEq(merchant.businessName, BUSINESS_NAME_1); // Other data should remain
    }

    function testMerchantCanDeactivateThemselves() public {
        // Register merchant
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        // Self-deactivate
        vm.prank(merchant1);
        vm.expectEmit(true, false, false, false);
        emit MerchantDeactivated(merchant1);

        registry.deactivateMyAccount();

        // Verify deactivation
        assertFalse(registry.isMerchantActive(merchant1));
        assertEq(registry.activeMerchants(), 0);
    }

    function testCannotDeactivateNonexistentMerchant() public {
        vm.expectRevert(abi.encodeWithSelector(MerchantRegistry.MerchantNotFound.selector, nonMerchant));
        registry.deactivateMerchant(nonMerchant);
    }

    function testCannotDeactivateAlreadyInactiveMerchant() public {
        // Register and then deactivate merchant
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        registry.deactivateMerchant(merchant1);

        // Try to deactivate again - should not revert but also not emit event
        uint256 activeCountBefore = registry.activeMerchants();
        registry.deactivateMerchant(merchant1);
        assertEq(registry.activeMerchants(), activeCountBefore);
    }

    function testNonOwnerCannotDeactivateOtherMerchants() public {
        // Register merchants
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        vm.prank(merchant2);
        registry.registerMerchant(BUSINESS_NAME_2, EMAIL_2);

        // merchant2 tries to deactivate merchant1
        vm.prank(merchant2);
        vm.expectRevert();
        registry.deactivateMerchant(merchant1);
    }

    // ============ REACTIVATION TESTS ============

    function testOwnerCanReactivateMerchant() public {
        // Register and deactivate merchant
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        registry.deactivateMerchant(merchant1);
        assertFalse(registry.isMerchantActive(merchant1));
        assertEq(registry.activeMerchants(), 0);

        // Reactivate merchant
        vm.expectEmit(true, false, false, true);
        emit MerchantRegistered(merchant1, BUSINESS_NAME_1);

        registry.reactivateMerchant(merchant1);

        // Verify reactivation
        assertTrue(registry.isMerchantActive(merchant1));
        assertEq(registry.activeMerchants(), 1);
    }

    function testCannotReactivateNonexistentMerchant() public {
        vm.expectRevert(abi.encodeWithSelector(MerchantRegistry.MerchantNotFound.selector, nonMerchant));
        registry.reactivateMerchant(nonMerchant);
    }

    function testCannotReactivateAlreadyActiveMerchant() public {
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        uint256 activeCountBefore = registry.activeMerchants();
        registry.reactivateMerchant(merchant1);
        assertEq(registry.activeMerchants(), activeCountBefore);
    }

    function testNonOwnerCannotReactivateMerchant() public {
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);
        registry.deactivateMerchant(merchant1);

        vm.prank(merchant2);
        vm.expectRevert();
        registry.reactivateMerchant(merchant1);
    }

    // ============ MERCHANT STATISTICS TESTS ============

    function testUpdateMerchantStats() public {
        // Register merchant
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        // Update stats (simulating payment gateway call)
        uint256 paymentAmount = 1000000; // $10 in some unit
        registry.updateMerchantStats(merchant1, paymentAmount);

        // Verify updated stats
        (uint256 totalPayments, uint256 totalVolume, uint256 registeredAt) = registry.getMerchantStats(merchant1);

        assertEq(totalPayments, 1);
        assertEq(totalVolume, paymentAmount);
        assertTrue(registeredAt > 0);

        // Update stats again
        registry.updateMerchantStats(merchant1, paymentAmount * 2);

        (totalPayments, totalVolume,) = registry.getMerchantStats(merchant1);
        assertEq(totalPayments, 2);
        assertEq(totalVolume, paymentAmount * 3); // 1M + 2M = 3M
    }

    function testCannotUpdateStatsForNonexistentMerchant() public {
        vm.expectRevert(abi.encodeWithSelector(MerchantRegistry.MerchantNotFound.selector, nonMerchant));
        registry.updateMerchantStats(nonMerchant, 1000);
    }

    function testGetMerchantStatsForNonexistentMerchant() public {
        vm.expectRevert(abi.encodeWithSelector(MerchantRegistry.MerchantNotFound.selector, nonMerchant));
        registry.getMerchantStats(nonMerchant);
    }

    // ============ PAGINATION TESTS ============

    function testGetMerchantsPagination() public {
        // Register 5 merchants
        address[] memory merchants = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            merchants[i] = address(uint160(i + 1));
            vm.prank(merchants[i]);
            registry.registerMerchant(
                string(abi.encodePacked("Business ", vm.toString(i))),
                string(abi.encodePacked("email", vm.toString(i), "@test.com"))
            );
        }

        // Test pagination
        IMerchantRegistry.Merchant[] memory page1 = registry.getMerchants(0, 3);
        assertEq(page1.length, 3);

        IMerchantRegistry.Merchant[] memory page2 = registry.getMerchants(3, 3);
        assertEq(page2.length, 2); // Only 2 remaining

        // Test out of bounds
        IMerchantRegistry.Merchant[] memory emptyPage = registry.getMerchants(10, 3);
        assertEq(emptyPage.length, 0);

        // Verify merchant data integrity
        for (uint256 i = 0; i < page1.length; i++) {
            assertEq(page1[i].merchantAddress, merchants[i]);
            assertTrue(page1[i].isActive);
        }
    }

    function testGetActiveMerchantsPagination() public {
        // Register 5 merchants
        for (uint256 i = 0; i < 5; i++) {
            address merchant = address(uint160(i + 1));
            vm.prank(merchant);
            registry.registerMerchant(
                string(abi.encodePacked("Business ", vm.toString(i))),
                string(abi.encodePacked("email", vm.toString(i), "@test.com"))
            );
        }

        // Deactivate merchants 2 and 4 (indices 1 and 3)
        registry.deactivateMerchant(address(uint160(2)));
        registry.deactivateMerchant(address(uint160(4)));

        // Get active merchants
        IMerchantRegistry.Merchant[] memory activeMerchants = registry.getActiveMerchants(0, 10);

        assertEq(activeMerchants.length, 3); // Only 3 active merchants

        // Verify all returned merchants are active
        for (uint256 i = 0; i < activeMerchants.length; i++) {
            assertTrue(activeMerchants[i].isActive);
        }

        // Test pagination of active merchants
        IMerchantRegistry.Merchant[] memory activePage1 = registry.getActiveMerchants(0, 2);
        assertEq(activePage1.length, 2);

        IMerchantRegistry.Merchant[] memory activePage2 = registry.getActiveMerchants(2, 2);
        assertEq(activePage2.length, 1);
    }

    // ============ SEARCH TESTS ============

    function testSearchMerchantsByName() public {
        // Register merchants with different names
        vm.prank(merchant1);
        registry.registerMerchant("Alice's Coffee Shop", EMAIL_1);

        vm.prank(merchant2);
        registry.registerMerchant("Bob's Coffee House", EMAIL_2);

        vm.prank(merchant3);
        registry.registerMerchant("Charlie's Books", EMAIL_3);

        // Search for "Coffee"
        IMerchantRegistry.Merchant[] memory coffeeShops = registry.searchMerchantsByName("Coffee");

        assertEq(coffeeShops.length, 2);

        // Verify results contain coffee shops
        bool foundAlice = false;
        bool foundBob = false;

        for (uint256 i = 0; i < coffeeShops.length; i++) {
            if (coffeeShops[i].merchantAddress == merchant1) foundAlice = true;
            if (coffeeShops[i].merchantAddress == merchant2) foundBob = true;
        }

        assertTrue(foundAlice);
        assertTrue(foundBob);

        // Search for non-existent term
        IMerchantRegistry.Merchant[] memory noResults = registry.searchMerchantsByName("Pizza");
        assertEq(noResults.length, 0);

        // Search with empty term
        IMerchantRegistry.Merchant[] memory emptySearch = registry.searchMerchantsByName("");
        assertEq(emptySearch.length, 0);
    }

    // ============ REGISTRY STATISTICS TESTS ============

    function testRegistryStats() public {
        // Initial state
        (uint256 total, uint256 active, uint256 inactive) = registry.getRegistryStats();
        assertEq(total, 0);
        assertEq(active, 0);
        assertEq(inactive, 0);

        // Register merchants
        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        vm.prank(merchant2);
        registry.registerMerchant(BUSINESS_NAME_2, EMAIL_2);

        vm.prank(merchant3);
        registry.registerMerchant(BUSINESS_NAME_3, EMAIL_3);

        // Check stats after registration
        (total, active, inactive) = registry.getRegistryStats();
        assertEq(total, 3);
        assertEq(active, 3);
        assertEq(inactive, 0);

        // Deactivate one merchant
        registry.deactivateMerchant(merchant2);

        (total, active, inactive) = registry.getRegistryStats();
        assertEq(total, 3);
        assertEq(active, 2);
        assertEq(inactive, 1);

        // Reactivate merchant
        registry.reactivateMerchant(merchant2);

        (total, active, inactive) = registry.getRegistryStats();
        assertEq(total, 3);
        assertEq(active, 3);
        assertEq(inactive, 0);
    }

    // ============ PAUSE/UNPAUSE TESTS ============

    function testOwnerCanPauseAndUnpause() public {
        // Test pause
        registry.pause();

        vm.prank(merchant1);
        vm.expectRevert();
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1);

        // Test unpause
        registry.unpause();

        vm.prank(merchant1);
        registry.registerMerchant(BUSINESS_NAME_1, EMAIL_1); // Should work now

        assertTrue(registry.isMerchantActive(merchant1));
    }

    function testNonOwnerCannotPause() public {
        vm.prank(merchant1);
        vm.expectRevert();
        registry.pause();
    }

    function testNonOwnerCannotUnpause() public {
        registry.pause();

        vm.prank(merchant1);
        vm.expectRevert();
        registry.unpause();
    }

    // ============ ACCESS CONTROL TESTS ============

    function testGetMerchantForNonexistentAddress() public {
        vm.expectRevert(abi.encodeWithSelector(MerchantRegistry.MerchantNotFound.selector, nonMerchant));
        registry.getMerchant(nonMerchant);
    }

    function testIsMerchantActiveForNonexistentAddress() public view {
        assertFalse(registry.isMerchantActive(nonMerchant));
    }

    // ============ EDGE CASES TESTS ============

    // function testMaxLengthBusinessNameAndEmail() public {
    //     // Test maximum allowed lengths (exactly 100 characters)
    //     string memory maxBusinessName = "Business Name That Is Exactly One Hundred Characters Long For Testing Maximum Length Limits X";
    //     string memory maxEmail = "verylongemailaddressthatexceedsthemaximumallowedlengthof100charactersfortestingpurposesxxxx@example.com";

    //     assertEq(bytes(maxBusinessName).length, 100);
    //     assertEq(bytes(maxEmail).length, 100);

    //     vm.prank(merchant1);
    //     registry.registerMerchant(maxBusinessName, maxEmail);

    //     IMerchantRegistry.Merchant memory merchant = registry.getMerchant(merchant1);
    //     assertEq(merchant.businessName, maxBusinessName);
    //     assertEq(merchant.email, maxEmail);
    // }

    function testZeroAddressHandling() public {
        // Test various functions with zero address
        assertFalse(registry.isMerchantActive(address(0)));

        vm.expectRevert(abi.encodeWithSelector(MerchantRegistry.MerchantNotFound.selector, address(0)));
        registry.getMerchant(address(0));
    }

    // ============ HELPER FUNCTIONS FOR TESTING ============

    function _registerTestMerchants(uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            address merchant = address(uint160(i + 1));
            vm.prank(merchant);
            registry.registerMerchant(
                string(abi.encodePacked("Business ", vm.toString(i))),
                string(abi.encodePacked("email", vm.toString(i), "@test.com"))
            );
        }
    }

    function _deactivateTestMerchants(address[] memory merchants) internal {
        for (uint256 i = 0; i < merchants.length; i++) {
            registry.deactivateMerchant(merchants[i]);
        }
    }
}
