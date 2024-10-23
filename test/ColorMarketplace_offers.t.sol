// Tests for making and accepting offers on listings

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

contract OfferTests is TestHelpers {

  function test_offerLowerThanListingPrice_accepted() public {
    // 1. List a token
    IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
    listingParams.buyoutPrice = 1 ether;

    // Warp to correct time for basic listing
    vm.warp(listingParams.startTime + 1);

    vm.prank(seller);
    color.createListing(listingParams);

    // 2. Make a lower offer
    uint256 listingId = 0;
    uint256 offerPrice = 0.8 ether;
    uint256 expirationTimestamp = block.timestamp + 1 days;

    vm.startPrank(buyer);
    erc20.mint(buyer, offerPrice);
    erc20.approve(address(color), offerPrice);
    color.offer(listingId, offerPrice, expirationTimestamp);
    vm.stopPrank();

    // 3. Seller accepts the offer
    vm.prank(seller);
    color.acceptOffer(listingId, buyer);

    // 4. Verify the outcome
    assertEq(erc721.ownerOf(0), buyer, "Buyer should now own the NFT");
    uint256 tax = color.calculatePlatformFee(offerPrice);
    assertEq(erc20.balanceOf(seller), offerPrice - tax, "Seller should receive the offer price minus fees");
  }

  function test_offerHigherThanListingPrice() public {
    // 1. List a token
    IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
    listingParams.buyoutPrice = 1 ether;

    // Warp to correct time for basic listing
    vm.warp(listingParams.startTime + 1);

    vm.prank(seller);
    color.createListing(listingParams);

    // 2. Make a higher offer
    uint256 listingId = 0;
    uint256 offerPrice = 1.2 ether;
    uint256 expirationTimestamp = block.timestamp + 1 days;

    vm.startPrank(buyer);
    erc20.mint(buyer, offerPrice);
    erc20.approve(address(color), offerPrice);
    color.offer(listingId, offerPrice, expirationTimestamp);
    vm.stopPrank();

    // 3. Seller accepts the offer
    vm.prank(seller);
    color.acceptOffer(listingId, buyer);

    // 4. Verify the outcome
    assertEq(erc721.ownerOf(0), buyer, "Buyer should now own the NFT");
    uint256 tax = color.calculatePlatformFee(offerPrice);
    assertEq(erc20.balanceOf(seller), offerPrice - tax, "Seller should receive the full offer price minus fees");
  }

  function test_cancelOffer_success() public {
    uint256 listingId = createAndApproveListing();

    IColorMarketplace.Listing memory listing = color.getListing(listingId);
    vm.warp(listing.startTime);

    vm.startPrank(buyer);
    erc20.mint(buyer, 3 ether);
    erc20.approve(address(color), 2 ether);
    vm.stopPrank();
    
    // Make an offer
    vm.prank(buyer);
    color.offer(listingId, 1 ether, block.timestamp + 1 hours);
    
    // Cancel the offer
    vm.prank(buyer);
    color.cancelOffer(listingId);
    
    // Verify the offer no longer exists
    IColorMarketplace.Offer memory offer = color.getOffer(listingId, buyer);
    assertEq(offer.offeror, address(0), "Offer should be deleted");
  }
  
}