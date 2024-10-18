// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

contract ListingStatusTests is TestHelpers {

    function test_createListing_statusOpen() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), NATIVE_ADDRESS);

        // Create the listing and capture the emitted event
        vm.prank(seller);
        vm.expectEmit(true, true, true, true);
        emit IColorMarketplace.ListingAdded(
            0, // Assuming this is the first listing
            address(erc721),
            seller,
            IColorMarketplace.Listing({
                listingId: 0,
                tokenOwner: seller,
                assetContract: address(erc721),
                tokenId: 0,
                startTime: 100,
                endTime: 300,  // startTime + secondsUntilEndTime
                currency: NATIVE_ADDRESS,
                buyoutPrice: 1 ether,
                status: IColorMarketplace.ListingStatus.Open,
                royaltyInfo: IColorMarketplace.RoyaltyInfo(address(0), 0)
            })
        );
        color.createListing(listingParams);

        // Fetch the created listing
        IColorMarketplace.Listing memory listing = color.getListing(0);  // Assuming this is the first listing

        // Assert that the listing status is Open
        assert(listing.status == IColorMarketplace.ListingStatus.Open);
    }

    function test_buyListing_statusClosed() public {
      // Setup
      uint256 tokenId = 0;
      uint256 price = 1 ether;
      
      // Create a listing
      IColorMarketplace.ListingParameters memory listingParams = getBasicListing(
          tokenId, 
          seller, 
          address(color), 
          address(erc721), 
          NATIVE_ADDRESS
      );

      // Get the expected listing ID
      uint256 expectedListingId = color.getTotalListings();

      vm.prank(seller);
      color.createListing(listingParams);

      // Verify initial status is Open
      IColorMarketplace.Listing memory listing = color.getListing(expectedListingId);
      assert(listing.status == IColorMarketplace.ListingStatus.Open);

      // Warp to a time within the sale window
      vm.warp(150);

      // Buy the listing
      vm.prank(buyer);
      vm.deal(buyer, price);
      vm.expectEmit(true, true, true, true);
      emit IColorMarketplace.NewSale(
          expectedListingId,
          address(erc721),
          seller,
          buyer,
          price
      );
      color.buy{value: price}(expectedListingId, buyer);

      // Verify the listing status is now Closed
      listing = color.getListing(expectedListingId);
      assert(listing.status == IColorMarketplace.ListingStatus.Closed);
    }

    function test_cancelListing_statusCancelled() public {
      // Setup
      uint256 tokenId = 0;
      
      // Create a listing
      IColorMarketplace.ListingParameters memory listingParams = getBasicListing(
          tokenId, 
          seller, 
          address(color), 
          address(erc721), 
          NATIVE_ADDRESS
      );

      // Get the expected listing ID
      uint256 expectedListingId = color.getTotalListings();

      vm.prank(seller);
      color.createListing(listingParams);

      // Verify initial status is Open
      IColorMarketplace.Listing memory listing = color.getListing(expectedListingId);
      assert(listing.status == IColorMarketplace.ListingStatus.Open);

      // Cancel the listing
      vm.prank(seller);
      vm.expectEmit(true, true, false, false);
      emit IColorMarketplace.ListingCancelled(expectedListingId, seller);
      color.cancelListing(expectedListingId);

      // Verify the listing status is now Cancelled
      listing = color.getListing(expectedListingId);
      assert(listing.status == IColorMarketplace.ListingStatus.Cancelled);
  }

    function test_bulkBuy_multipleStatusChanges() public {
      // Setup
      uint256 numListings = 3;
      uint256 price = 1 ether;
      
      uint256[] memory listingIds = new uint256[](numListings);
      address[] memory buyers = new address[](numListings);
      address[] memory currencies = new address[](numListings);
      uint256[] memory prices = new uint256[](numListings);

      // Create multiple listings
      for (uint256 i = 0; i < numListings; i++) {
          IColorMarketplace.ListingParameters memory listingParams = getBasicListing(
              i, 
              seller, 
              address(color), 
              address(erc721), 
              NATIVE_ADDRESS
          );
          
          vm.prank(seller);
          color.createListing(listingParams);
          
          listingIds[i] = color.getTotalListings() - 1;
          buyers[i] = buyer;
          currencies[i] = NATIVE_ADDRESS;
          prices[i] = price;

          // Verify initial status is Open
          IColorMarketplace.Listing memory listing = color.getListing(listingIds[i]);
          assert(listing.status == IColorMarketplace.ListingStatus.Open);
      }

      // Warp to a time within the sale window
      vm.warp(150);

      // Perform bulk buy
      vm.prank(buyer);
      vm.deal(buyer, price * numListings);
      color.bulkBuy{value: price * numListings}(listingIds, buyers);

      // Verify all listings are now Closed
      for (uint256 i = 0; i < numListings; i++) {
          IColorMarketplace.Listing memory listing = color.getListing(listingIds[i]);
          assert(listing.status == IColorMarketplace.ListingStatus.Closed);
      }
  }

    function test_cancelListings_multipleStatusChanges() public {
      // Setup
      uint256 numListings = 3;
      
      uint256[] memory listingIds = new uint256[](numListings);

      // Create multiple listings
      for (uint256 i = 0; i < numListings; i++) {
          IColorMarketplace.ListingParameters memory listingParams = getBasicListing(
              i, 
              seller, 
              address(color), 
              address(erc721), 
              NATIVE_ADDRESS
          );
          
          vm.prank(seller);
          color.createListing(listingParams);
          
          listingIds[i] = color.getTotalListings() - 1;

          // Verify initial status is Open
          IColorMarketplace.Listing memory listing = color.getListing(listingIds[i]);
          assert(listing.status == IColorMarketplace.ListingStatus.Open);
      }

      // Cancel multiple listings
      // vm.prank(seller);
      for (uint256 i = 0; i < numListings; i++) {
          vm.prank(seller);
          vm.expectEmit(true, true, false, false);
          emit IColorMarketplace.ListingCancelled(listingIds[i], seller);
          color.cancelListing(listingIds[i]);
      }

      // Verify all listings are now Cancelled
      for (uint256 i = 0; i < numListings; i++) {
          IColorMarketplace.Listing memory listing = color.getListing(listingIds[i]);
          assert(listing.status == IColorMarketplace.ListingStatus.Cancelled);
      }
    }


    // A listing may still have the open status but the expired time may have past.
    // Since this is on chain, we don't want to have to send update messages to close the listing
    // after the time happens and waste gas. So This case must be checked for in marketplace backend.
    function test_revert_buyExpiredListing() public {
      // Setup
      uint256 tokenId = 0;
      uint256 price = 1 ether;
      uint256 listingDuration = 1 hours;
      
      // Create a listing with a specific duration
      IColorMarketplace.ListingParameters memory listingParams = getBasicListing(
          tokenId, 
          seller, 
          address(color), 
          address(erc721), 
          NATIVE_ADDRESS
      );

      // Modify the listing parameters for this specific test
      listingParams.startTime = block.timestamp;
      listingParams.secondsUntilEndTime = listingDuration;
      listingParams.buyoutPrice = price;

      // Get the expected listing ID
      uint256 expectedListingId = color.getTotalListings();

      vm.prank(seller);
      color.createListing(listingParams);

      // Verify initial status is Open
      IColorMarketplace.Listing memory listing = color.getListing(expectedListingId);
      assert(listing.status == IColorMarketplace.ListingStatus.Open);

      // Warp to a time past the listing's end time
      vm.warp(block.timestamp + listingDuration + 1 seconds);

      // Attempt to buy the expired listing
      vm.prank(buyer);
      vm.deal(buyer, price);
      
      // Expect the transaction to revert
      vm.expectRevert(
        abi.encodeWithSelector(
          IColorMarketplace.InactiveListing.selector,
          listing.startTime,
          listing.endTime,
          block.timestamp
          )
      );
      color.buy{value: price}(expectedListingId, buyer);

      // Verify the listing is still Open (not Closed or Expired)
      listing = color.getListing(expectedListingId);
      assert(listing.status == IColorMarketplace.ListingStatus.Open);
      
      // Verify the current time is indeed past the listing's end time
      assert(block.timestamp > listing.endTime);
    }

    function test_revert_buyCancelledListing() public {
        // Test that trying to buy a cancelled listing reverts
    }

    function test_revert_cancelClosedListing() public {
        // Test that trying to cancel a closed listing reverts
    }

    function test_revert_cancelExpiredListing() public {
        // Test that trying to cancel an expired listing reverts
    }

    function test_offerOnExpiredListing() public {
        // Test behavior when making an offer on an expired listing
    }

    function test_acceptOfferClosedListing() public {
        // Test behavior when trying to accept an offer on a closed listing
    }

    function test_listingStatus_afterMarketplacePause() public {
        // Test listing statuses after the marketplace is paused (if pause functionality exists)
    }

    function test_listingStatus_afterMarketplaceUnpause() public {
        // Test listing statuses after the marketplace is unpaused (if pause functionality exists)
    }
}