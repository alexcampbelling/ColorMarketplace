// Tests for direct sales

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

contract DirectSalesTests is TestHelpers {

    /* Misc tests */

    function test_state_initial() public view {
        uint256 totalListings = color.totalListings();
        assertEq(totalListings, 0);
    }

    function test_listing_burned_success() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);

        // Check if listing count incremented
        assertEq(color.totalListings(), 1);

        // Burn the token
        vm.prank(seller);
        erc721.burn(0);

        vm.warp(150);

        // Check if listing valid
        assertEq(color.checkListingValid(0), false);
    
        // Check no valid listings
        assertEq(color.getAllValidListings().length, 0);
    }

    /* Create Listing tests */

    function test_createListing() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);
        assertEq(color.totalListings(), 1);
    }

    function test_createListing_721_success() public {

        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);

        // Check if listing count incremented
        assertEq(color.totalListings(), 1);

        // Check if listing details are correct
        IColorMarketplace.Listing memory listing = color.getListing(0);
        assertEq(listing.listingId, 0);
        assertEq(listing.tokenOwner, seller);
        assertEq(listing.assetContract, address(erc721));
        assertEq(listing.tokenId, 0);
        assertEq(listing.startTime, 100); // todo: does this matter on direct?
        assertEq(listing.endTime, 300);
        assertEq(listing.currency, address(erc20));
        assertEq(listing.reservePrice, 0);
        assertEq(listing.buyoutPrice, 1 ether);
        assertEq(uint256(listing.listingType), uint256(IColorMarketplace.ListingType.Direct));
    }

    function test_revert_createListing_NotDirectListing() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));
        
        // Spoof the type
        listingParams.listingType = IColorMarketplace.ListingType.Auction;

        vm.prank(seller);
        color.createListing(listingParams);

        // Buy the auction listing with buy() instead of offer() will trigger this not direct listing revert
        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 totalPrice = 1 ether;

        vm.warp(150);

        // Mint requisite total price to buyer.
        vm.prank(buyer);
        erc20.mint(buyer, totalPrice*2);

        vm.prank(buyer);
        erc20.approve(address(color), totalPrice*2);

        // Buy token
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.NotDirectListing.selector)
        );
        color.buy(listingId, buyFor, address(erc20), totalPrice);
    }

    function test_revert_createListing_NotWithinSaleWindow() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);

        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 totalPrice = 1 ether;

        // Time has elapsed (basic listing helper puts end time to 300)
        vm.warp(350);

        // Mint requisite total price to buyer.
        vm.prank(buyer);
        erc20.mint(buyer, totalPrice*2);

        vm.prank(buyer);
        erc20.approve(address(color), totalPrice*2);

        vm.prank(buyer);
        vm.expectRevert(
        abi.encodeWithSelector(
            IColorMarketplace.InactiveListing.selector,
            100, // startTime
            300, // endTime
            350  // currentTime
            )
        );
        color.buy(listingId, buyFor, address(erc20), totalPrice);
    }

    // This case is for when buyer tries to buy with native token.
    function test_revert_createListing_InvalidMsgValue() public {
        // If we want to buy via native token, we spoof the currency address as a preset address 
        // todo: move to testhelpers
        address native = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        // Spoof the currency address to use native L1 currency
        listingParams.currency = native;

        vm.prank(seller);
        color.createListing(listingParams);

        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 totalPrice = 1 ether;

        // Time has elapsed (basic listing helper puts end time to 300)
        vm.warp(150);

        // Give buyer the needed eth plus some
        vm.deal(buyer, 2 ether);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.InvalidMsgValue.selector)
        );
        // Minus 1 here is to trigger the error
        color.buy{value: totalPrice-1}(listingId, buyFor, native, totalPrice);
    }

    // This revert is for approval and ownership check for tokens when listing
    function test_revert_createListing_TokenNotValidOrApproved() public {
        // IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20), false);

        // Sample listing parameters.
        address assetContract = address(erc721);
        uint256 tokenId = 0;
        uint256 startTime = 100;
        uint256 secondsUntilEndTime = 200;
        address currency = address(erc20);
        uint256 reservePrice;
        uint256 buyoutPrice = 1 ether;
        IColorMarketplace.ListingType listingType = IColorMarketplace.ListingType.Direct;

        // Mint token for seller
        _setupERC721BalanceForSeller(seller, 1);

        // Approve Marketplace to transfer token.
        // NO APPROVAL HERE
        // vm.prank(_seller);
        // erc721.setApprovalForAll(address(_color), true);

        // List token
        IColorMarketplace.ListingParameters memory listingParams = IColorMarketplace.ListingParameters(
            assetContract,
            tokenId,
            startTime,
            secondsUntilEndTime,
            currency,
            reservePrice,
            buyoutPrice,
            listingType
        );

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.TokenNotValidOrApproved.selector)
        );
        color.createListing(listingParams);
    }

    // Here we don't approve the marketplace to transfer the payment currency
    function test_revert_createListing_InsufficientBalanceOrAllowance() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);

        // Create buy options
        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 quantityToBuy = 1;
        uint256 totalPrice = 1 ether;

        vm.warp(150);

        // Mint requisite total price to buyer.
        vm.prank(buyer);
        erc20.mint(buyer, totalPrice);

        // NO APPROVAL HERE
        // vm.prank(buyer);
        // erc20.approve(address(color), totalPrice);

        // Buy token
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.InsufficientBalanceOrAllowance.selector)
        );
        color.buy(listingId, buyFor, address(erc20), totalPrice);
    }

    /* Buy Direct listing Tests */

    // Here we buy a listing for the exact listing price
    function test_buyDirect_erc20_success() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);

        // Check if listing count incremented
        assertEq(color.totalListings(), 1);

        // Create buy options
        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 quantityToBuy = 1;
        uint256 totalPrice = 1 ether;

        vm.warp(150);

        // Mint requisite total price to buyer.
        vm.prank(buyer);
        erc20.mint(buyer, totalPrice*2);

        vm.prank(buyer);
        erc20.approve(address(color), totalPrice*2);

        // Buy token
        vm.prank(buyer);
        color.buy(listingId, buyFor, address(erc20), totalPrice);

        // Check if listing doesn't exist
        // todo alex: check via checking status now
        // Check if buyer has token
        assertEq(erc721.balanceOf(buyer), 1);
        // Check if seller has received payment (calculating minus tax, todo: enhance this to include royalties if any)
        uint256 tax = color.calculatePlatformFee(totalPrice);
        assertEq(erc20.balanceOf(seller), 1 ether - tax);
    }

    function test_buyDirect_eth_success() public {

    }

    // Here we give an offer to a listing (this means the listing, although a direct sale can receive offers lower 
    // than the listing amount and the seller can consider then accept them)
    function test_bidListing_success() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);

        // Create offer options
        uint256 listingId = 0;
        address currency = address(erc20);
        uint256 pricePerToken = 1 ether;
        uint256 expirationTimestamp = 500;

        vm.warp(150);

        // Mint requisite total price to buyer.
        vm.prank(buyer);
        erc20.mint(buyer, 1 ether);

        vm.prank(buyer);
        erc20.approve(address(color), 1 ether);

        // Check that the offer emit event was seen in logs
        vm.expectEmit(true, false, false, true, address(color));
        emit IColorMarketplace.NewOffer(listingId, buyer, IColorMarketplace.ListingType.Direct, pricePerToken, currency);

        // Offer for token
        vm.prank(buyer);
        color.offer(listingId, currency, pricePerToken, expirationTimestamp);

        vm.warp(180);

        // Accept the offer
        vm.prank(seller);
        color.acceptOffer(listingId, buyer, currency, pricePerToken);

        // Check if listing doesn't exist
        // todo alex: check status now here
        // Check if buyer has token
        assertEq(erc721.balanceOf(buyer), 1);
        // Check if seller has received payment (calculating minus tax, todo: enhance this to include royalties if any)
        uint256 tax = color.calculatePlatformFee(pricePerToken);
        assertEq(erc20.balanceOf(seller), 1 ether - tax);   
    }

    function test_buyDirect_erc20_fractional_amount_success() public {
        // Set up a listing with a fractional price
        uint256 fractionalPrice = 0.5 ether; // 0.5 IP
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20));
        listingParams.buyoutPrice = fractionalPrice;

        vm.prank(seller);
        color.createListing(listingParams);

        // Create buy options
        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 quantityToBuy = 1;
        uint256 totalPrice = fractionalPrice;

        vm.warp(150);

        // Mint requisite total price to buyer.
        vm.prank(buyer);
        erc20.mint(buyer, totalPrice * 2);

        vm.prank(buyer);
        erc20.approve(address(color), totalPrice * 2);

        // Buy token
        vm.prank(buyer);
        color.buy(listingId, buyFor, address(erc20), totalPrice);

        // Check if listing doesn't exist
        // todo alex: check status now here
        // Check if buyer has token
        assertEq(erc721.balanceOf(buyer), 1);
        // Check if seller has received payment (calculating minus tax)
        uint256 tax = color.calculatePlatformFee(totalPrice);
        assertEq(erc20.balanceOf(seller), fractionalPrice - tax);
    }

    function test_buyDirect_with_fractional_native_currency() public {
    // Set up a listing with a fractional price
    uint256 fractionalPrice = 0.5 ether; // 0.5 native token
    
    IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color), address(erc721), NATIVE_ADDRESS); // Use address(0) for native token
    listingParams.buyoutPrice = fractionalPrice;

    vm.prank(seller);
    color.createListing(listingParams);

    // Create buy options
    uint256 listingId = 0;
    address buyFor = address(buyer);
    uint256 quantityToBuy = 1;
    uint256 totalPrice = fractionalPrice;

    vm.warp(150);

    // Ensure the buyer has enough native currency
    vm.deal(buyer, totalPrice * 2); // Give the buyer double the fractional price

    // Buy token using fractional native currency
    vm.prank(buyer);
    color.buy{value: totalPrice}(listingId, buyFor, NATIVE_ADDRESS, totalPrice); // Use address(0) for native token

    // Check if listing doesn't exist
    // todo alex: check status now here
    // Check if buyer has token
    assertEq(erc721.balanceOf(buyer), 1);
    // Check if seller has received payment (calculating minus tax)
    uint256 tax = color.calculatePlatformFee(totalPrice);
    assertEq(seller.balance, fractionalPrice - tax);
}
}
