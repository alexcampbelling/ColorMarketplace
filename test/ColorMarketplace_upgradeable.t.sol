// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./TestHelpers.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract ColorMarketplaceUpgradeableTest is TestHelpers {
    function test_upgrade_success() public {

      // Deploy new implementation
      ColorMarketplace newImplementation = new ColorMarketplace();

      // Perform upgrade
      Upgrades.upgradeProxy(
          payable(proxy),
          "ColorMarketplace.sol",
          ""
      );

      // Verify upgrade
      bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
      bytes32 implementationBytes;
      assembly {
          implementationBytes := sload(implementationSlot)
      }
      address implementationAddress = address(uint160(uint256(implementationBytes)));
      assertEq(implementationAddress, address(newImplementation), "Upgrade failed: implementation address mismatch");
    }

    // todo alex: this test exists elsewhere, this should instead test if upgrading does
    // not mess with the current state of listings made.
    function test_createListing_success() public {
        // Use the erc20 address from BaseTest
        address currency = address(erc20);

        // Setup ERC721 for seller
        _setupERC721BalanceForSeller(seller, 1);
        
        // Approve Marketplace to transfer token
        vm.prank(seller);
        erc721.setApprovalForAll(address(color), true);

        // Create listing
        vm.prank(seller);
        color.createListing(
            IColorMarketplace.ListingParameters({
                assetContract: address(erc721),
                tokenId: 0,
                startTime: block.timestamp,
                secondsUntilEndTime: 1 days,
                currency: currency,
                buyoutPrice: 1 ether
            })
        );

        // Verify listing
        IColorMarketplace.Listing memory listing = color.getListing(0);
        assertEq(listing.tokenOwner, seller);
        assertEq(listing.assetContract, address(erc721));
        assertEq(listing.tokenId, 0);
        assertEq(listing.buyoutPrice, 1 ether);
        assertEq(listing.currency, currency);
    }
}