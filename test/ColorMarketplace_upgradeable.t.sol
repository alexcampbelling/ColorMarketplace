// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./TestHelpers.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/ColorMarketplace.sol";
import {IColorMarketplace} from "../src/IColorMarketplace.sol";
import "./utils/ColorV2Mock.sol";


contract ColorMarketplaceUpgradeableTest is TestHelpers {

    function test_upgrade_success() public {
        // Check initial version
        assertEq(color.chainVersion(), 1, "Initial chain version should be 1");

        // Log the defaultAdmin address
        console.log("Default Admin address:", defaultAdmin);

        // Check if defaultAdmin has the DEFAULT_ADMIN_ROLE
        bool hasAdminRole = color.hasRole(color.DEFAULT_ADMIN_ROLE(), defaultAdmin);
        console.log("Does defaultAdmin have DEFAULT_ADMIN_ROLE?", hasAdminRole);

        // Log the address that's actually trying to perform the upgrade
        console.log("Address trying to upgrade:", address(this));

        // Check if the test contract has the DEFAULT_ADMIN_ROLE
        bool testContractHasAdminRole = color.hasRole(color.DEFAULT_ADMIN_ROLE(), address(this));
        console.log("Does test contract have DEFAULT_ADMIN_ROLE?", testContractHasAdminRole);

        // Create a listing before upgrade
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(
            0, // tokenId
            seller,
            address(color),
            address(erc721),
            address(erc20)
        );

        vm.prank(seller);
        uint256 listingId = 0;
        color.createListing(listingParams);

        // Verify the listing exists
        IColorMarketplace.Listing memory listing = color.getListing(listingId);
        assertEq(listing.tokenId, 0, "Listing should exist with correct tokenId");

        // // Perform upgrade
        // vm.prank(defaultAdmin);
        // Upgrades.upgradeProxy(
        //     address(proxy),
        //     "ColorV2Mock.sol:ColorMarketplaceV2",
        //     abi.encodeCall(ColorMarketplaceV2.initialize, ()),
        //     defaultAdmin // This is the tryCaller parameter
        // );

        // Prepare the upgrade call
        bytes memory data = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (
                address(new ColorMarketplaceV2()),
                abi.encodeCall(ColorMarketplaceV2.initialize, ())
            )
        );

        // Perform upgrade
        vm.prank(defaultAdmin);
        (bool success, ) = address(proxy).call(data);
        require(success, "Upgrade failed");

        // Cast to V2
        ColorMarketplaceV2 colorV2 = ColorMarketplaceV2(payable(proxy));

        // Verify upgrade
        assertEq(address(colorV2), proxy, "Proxy address should not change");
        assertEq(colorV2.chainVersion(), 2, "Chain version should be updated to 2");

        // Check new feature
        assertFalse(colorV2.getNewFeature(), "New feature should initially be false");
        vm.prank(defaultAdmin);
        colorV2.setNewFeature(true);
        assertTrue(colorV2.getNewFeature(), "New feature should be set to true");

        // Verify that the existing listing is still intact
        IColorMarketplace.Listing memory listingAfterUpgrade = colorV2.getListing(listingId);
        assertEq(listingAfterUpgrade.tokenId, 0, "Listing should still exist after upgrade");
        assertEq(listingAfterUpgrade.tokenOwner, seller, "Listing owner should remain the same");
        assertEq(listingAfterUpgrade.assetContract, address(erc721), "Asset contract should remain the same");
        assertEq(listingAfterUpgrade.buyoutPrice, 1 ether, "Buyout price should remain the same");

        // Test that we can still interact with the upgraded contract
        erc20.mint(buyer, 2 ether);
        vm.prank(buyer);
        erc20.approve(address(colorV2), 2 ether);

        vm.warp(150);
        vm.prank(buyer);
        colorV2.buy(listingId, address(buyer));

        // Verify the listing is now sold
        IColorMarketplace.Listing memory soldListing = colorV2.getListing(listingId);
        assertEq(uint8(soldListing.status), uint8(IColorMarketplace.ListingStatus.Closed), "Listing status should be Sold");
        // Verify token ownership transfer
        assertEq(erc721.ownerOf(0), buyer, "Buyer should now own the token");

        // Verify payment transfer
        uint256 platformFee = colorV2.calculatePlatformFee(1 ether);
        assertEq(erc20.balanceOf(seller), 1 ether - platformFee, "Seller should receive payment minus platform fee");
    }
}