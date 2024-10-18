// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AdminActionsTests is TestHelpers {
    // Test-specific variables
    address public newFeeRecipient;
    uint256 public newFeeBps;
    address public nonAdminUser;
    address public newTokenAddress;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    
    function setUp() public override {
        // Call the parent setUp function
        super.setUp();

        // Initialize test-specific variables
        newFeeRecipient = getActor(10);
        newFeeBps = 250; // 2.5%
        nonAdminUser = getActor(11);
        newTokenAddress = getActor(12);
    }

    // Platform Fee Tests

    function test_setPlatformFeeInfo_success() public {
        // Test successful update of platform fee info
        vm.prank(defaultAdmin);
        bool result = color.setPlatformFeeInfo(newFeeRecipient, newFeeBps);

        assertTrue(result, "setPlatformFeeInfo should return true on successful update");

        (address actualRecipient, uint16 actualFeeBps) = color.getPlatformFeeInfo();
        assertEq(actualRecipient, newFeeRecipient, "Fee recipient should be updated");
        assertEq(actualFeeBps, newFeeBps, "Fee BPS should be updated");
    }

    function test_setPlatformFeeInfo_emitsEvent() public {
        // Test event emission on platform fee info update
        vm.expectEmit(true, false, false, true);
        emit IColorMarketplace.PlatformFeeInfoUpdated(newFeeRecipient, newFeeBps);

        vm.prank(defaultAdmin);
        bool result = color.setPlatformFeeInfo(newFeeRecipient, newFeeBps);

        assertTrue(result, "setPlatformFeeInfo should return true on successful update");
    }

    function test_setPlatformFeeInfo_sameValues() public {
        // Test setting platform fee info to the same values
        vm.startPrank(defaultAdmin);
        color.setPlatformFeeInfo(newFeeRecipient, newFeeBps);
        bool result = color.setPlatformFeeInfo(newFeeRecipient, newFeeBps);
        vm.stopPrank();

        assertFalse(result, "Should return false when setting to the same values");
    }

    function test_setPlatformFeeInfo_zeroAddress() public {
        // Test setting platform fee recipient to zero address
        vm.prank(defaultAdmin);
        vm.expectRevert(IColorMarketplace.InvalidFeeRecipient.selector);
        color.setPlatformFeeInfo(address(0), newFeeBps);
    }

    function test_setPlatformFeeInfo_revertInvalidFee() public {
        // Test revert when fee is set above 100%
        vm.prank(defaultAdmin);
        vm.expectRevert(IColorMarketplace.InvalidPlatformFeeBps.selector);
        color.setPlatformFeeInfo(newFeeRecipient, 10001);
    }

    // ERC20 Whitelist Tests

    function test_erc20WhiteListAdd_success() public {
        // Ensure the token is not already whitelisted
        assertFalse(color.isErc20Whitelisted(newTokenAddress), "Token should not be whitelisted initially");

        vm.mockCall(newTokenAddress, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1000000));

        vm.prank(defaultAdmin);
        bool result = color.erc20WhiteListAdd(newTokenAddress);

        assertTrue(result, "Should return true on successful addition");
        assertTrue(color.isErc20Whitelisted(newTokenAddress), "New token should be whitelisted");
    }

    function test_erc20WhiteListAdd_revertInvalidERC20() public {
        // Test revert when trying to add an invalid ERC20 token
        address invalidToken = address(0x999);
        vm.mockCall(invalidToken, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));

        vm.prank(defaultAdmin);
        vm.expectRevert(IColorMarketplace.InvalidERC20.selector);
        color.erc20WhiteListAdd(invalidToken);
    }

    function test_erc20WhiteListRemove_success() public {
        // Ensure the token is whitelisted first
        vm.prank(defaultAdmin);
        color.erc20WhiteListAdd(address(erc20));
        assertTrue(color.isErc20Whitelisted(address(erc20)), "Token should be whitelisted initially");

        vm.prank(defaultAdmin);
        bool result = color.erc20WhiteListRemove(address(erc20));

        assertTrue(result, "Should return true on successful removal");
        assertFalse(color.isErc20Whitelisted(address(erc20)), "Token should be removed from whitelist");
    }

    function test_erc20WhiteListAdd_revertNonAdmin() public {
        vm.prank(nonAdminUser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonAdminUser, DEFAULT_ADMIN_ROLE));
        color.erc20WhiteListAdd(newTokenAddress);
    }

    function test_erc20WhiteListRemove_revertNonAdmin() public {
        vm.prank(nonAdminUser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonAdminUser, DEFAULT_ADMIN_ROLE));
        color.erc20WhiteListRemove(address(erc20));
    }

    function test_setPlatformFeeInfo_revertNonAdmin() public {
        vm.prank(nonAdminUser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonAdminUser, DEFAULT_ADMIN_ROLE));
        color.setPlatformFeeInfo(newFeeRecipient, newFeeBps);
    }

    function test_erc20WhiteListAdd_alreadyWhitelisted() public {
        vm.mockCall(newTokenAddress, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1000000));

        vm.startPrank(defaultAdmin);
        color.erc20WhiteListAdd(newTokenAddress);
        assertTrue(color.isErc20Whitelisted(newTokenAddress), "Token should be whitelisted");
        
        bool result = color.erc20WhiteListAdd(newTokenAddress);
        vm.stopPrank();

        assertFalse(result, "Should return false when adding already whitelisted token");
        assertTrue(color.isErc20Whitelisted(newTokenAddress), "Token should still be whitelisted");
    }

    function test_erc20WhiteListRemove_notWhitelisted() public {
        // Test removing a token that's not whitelisted
        vm.prank(defaultAdmin);
        color.erc20WhiteListRemove(newTokenAddress);

        assertFalse(color.isErc20Whitelisted(newTokenAddress), "Token should not be whitelisted");
    }
}