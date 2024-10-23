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

    function test_transferAdminOwnership_success() public {
        address newAdmin = getActor(20);
        
        vm.prank(defaultAdmin);
        color.transferAdminOwnership(newAdmin);

        assertTrue(color.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), "New admin should have admin role");
        assertFalse(color.hasRole(DEFAULT_ADMIN_ROLE, defaultAdmin), "Old admin should not have admin role");
    }

    function test_transferAdminOwnership_revertZeroAddress() public {
        vm.prank(defaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.AdminTransferFailed.selector, address(0)));
        color.transferAdminOwnership(address(0));
    }

    function test_transferAdminOwnership_revertNonAdmin() public {
        address newAdmin = getActor(20);
        vm.prank(nonAdminUser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonAdminUser, DEFAULT_ADMIN_ROLE));
        color.transferAdminOwnership(newAdmin);
    }

    function test_adminCancelListing_success() public {
        uint256 listingId = createAndApproveListing();
        
        vm.prank(defaultAdmin);
        color.adminCancelListing(listingId);

        IColorMarketplace.Listing memory listing = color.getListing(listingId);
        assertEq(uint8(listing.status), uint8(IColorMarketplace.ListingStatus.Cancelled), "Listing should be cancelled");
    }

    function test_adminCancelListing_revertNotOpen() public {
        uint256 listingId = createAndApproveListing();
        
        vm.prank(defaultAdmin);
        color.adminCancelListing(listingId);

        vm.prank(defaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.ListingNotOpen.selector, listingId, IColorMarketplace.ListingStatus.Cancelled));
        color.adminCancelListing(listingId);
    }

    function test_adminCancelListing_revertNonAdmin() public {
        uint256 listingId = createAndApproveListing();
        
        vm.prank(nonAdminUser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonAdminUser, DEFAULT_ADMIN_ROLE));
        color.adminCancelListing(listingId);
    }

    function test_adminCancelOffer_success() public {
        uint256 listingId = createAndApproveListing();
        uint256 offerPrice = 1 ether;
        uint256 expirationTime = block.timestamp + 1 days;

        // Warp to the start time of the listing
        IColorMarketplace.Listing memory listing = color.getListing(listingId);
        vm.warp(listing.startTime);

        erc20.mint(buyer, offerPrice);
        vm.prank(buyer);
        erc20.approve(address(color), offerPrice);

        vm.prank(buyer);
        color.offer(listingId, offerPrice, expirationTime);

        // Verify the offer was created
        IColorMarketplace.Offer memory offerBefore = color.getOffer(listingId, buyer);
        assertEq(offerBefore.offeror, buyer, "Offer should exist before cancellation");

        vm.prank(defaultAdmin);
        color.adminCancelOffer(listingId, buyer);

        // Verify the offer was cancelled
        IColorMarketplace.Offer memory offerAfter = color.getOffer(listingId, buyer);
        assertEq(offerAfter.offeror, address(0), "Offer should be deleted after cancellation");
    }

    function test_adminCancelOffer_revertOfferNotFound() public {
        uint256 listingId = createAndApproveListing();
        
        vm.prank(defaultAdmin);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.OfferNotFound.selector, listingId, buyer));
        color.adminCancelOffer(listingId, buyer);
    }

    function test_adminCancelOffer_revertNonAdmin() public {
        uint256 listingId = createAndApproveListing();
        uint256 offerPrice = 1 ether;
        uint256 expirationTime = block.timestamp + 1 days;

        erc20.mint(buyer, offerPrice);
        vm.prank(buyer);
        erc20.approve(address(color), offerPrice);

        // Warp to the start time of the listing
        IColorMarketplace.Listing memory listing = color.getListing(listingId);
        vm.warp(listing.startTime);

        vm.prank(buyer);
        color.offer(listingId, offerPrice, expirationTime);

        vm.prank(nonAdminUser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nonAdminUser, DEFAULT_ADMIN_ROLE));
        color.adminCancelOffer(listingId, buyer);
    }
}