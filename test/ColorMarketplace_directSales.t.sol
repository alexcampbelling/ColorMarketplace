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
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

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
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

        vm.prank(seller);
        color.createListing(listingParams);
        assertEq(color.totalListings(), 1);
    }

    function test_createListing_721_success() public {

        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

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
        assertEq(listing.quantity, 1);
        assertEq(listing.currency, address(erc20));
        assertEq(listing.reservePricePerToken, 0);
        assertEq(listing.buyoutPricePerToken, 1 ether);
        assertEq(uint256(listing.tokenType), uint256(IColorMarketplace.TokenType.ERC721));
        assertEq(uint256(listing.listingType), uint256(IColorMarketplace.ListingType.Direct));
    }

    function test_revert_createListing_NotDirectListing() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));
        
        // Spoof the type
        listingParams.listingType = IColorMarketplace.ListingType.Auction;

        vm.prank(seller);
        color.createListing(listingParams);

        // Buy the auction listing with buy() instead of offer() will trigger this not direct listing revert
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
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.NotDirectListing.selector)
        );
        color.buy(listingId, buyFor, quantityToBuy, address(erc20), totalPrice);
    }

    // Try to buy more tokens than available (needs correct price included for this failure)
    function test_revert_createListing_InvalidTokenAmount() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

        vm.prank(seller);
        color.createListing(listingParams);

        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 quantityToBuy = 2; // This is where the error comes from
        uint256 totalPrice = quantityToBuy* 1 ether;

        vm.warp(150);

        // Mint requisite total price to buyer.
        vm.prank(buyer);
        erc20.mint(buyer, totalPrice*2);

        vm.prank(buyer);
        erc20.approve(address(color), totalPrice*2);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.InvalidTokenAmount.selector)
        );
        color.buy(listingId, buyFor, quantityToBuy, address(erc20), totalPrice);
    }

    function test_revert_createListing_NotWithinSaleWindow() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

        vm.prank(seller);
        color.createListing(listingParams);

        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 quantityToBuy = 1;
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
            abi.encodeWithSelector(IColorMarketplace.NotWithinSaleWindow.selector)
        );
        color.buy(listingId, buyFor, quantityToBuy, address(erc20), totalPrice);
    }

    // This case is for when buyer tries to buy with native token.
    function test_revert_createListing_InvalidMsgValue() public {
        // If we want to buy via native token, we spoof the currency address as a preset address 
        // todo: move to testhelpers
        address native = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

        // Spoof the currency address to use native L1 currency
        listingParams.currency = native;

        vm.prank(seller);
        color.createListing(listingParams);

        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 quantityToBuy = 1;
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
        color.buy{value: totalPrice-1}(listingId, buyFor, quantityToBuy, native, totalPrice);
    }

    // This revert is for approval and ownership check for tokens when listing
    function test_revert_createListing_TokenNotValidOrApproved() public {
        // IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

        // Sample listing parameters.
        address assetContract = address(erc721);
        uint256 tokenId = 0;
        uint256 startTime = 100;
        uint256 secondsUntilEndTime = 200;
        uint256 quantityToList = 1;
        address currency = address(erc20);
        uint256 reservePricePerToken; // not an auction, does not need to be set
        uint256 buyoutPricePerToken = 1 ether;
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
            quantityToList,
            currency,
            reservePricePerToken,
            buyoutPricePerToken,
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
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

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
        color.buy(listingId, buyFor, quantityToBuy, address(erc20), totalPrice);
    }

    /* Buy Direct listing Tests */

    // Here we buy a listing for the exact listing price
    function test_buyDirect_erc20_success() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

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
        color.buy(listingId, buyFor, quantityToBuy, address(erc20), totalPrice);

        // Check if listing doesn't exist
        assertEq(color.getListing(0).quantity, 0);
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
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

        vm.prank(seller);
        color.createListing(listingParams);

        // Create offer options
        uint256 listingId = 0;
        uint256 quantityWanted = 1;
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
        emit IColorMarketplace.NewOffer(listingId, buyer, IColorMarketplace.ListingType.Direct, quantityWanted, pricePerToken * quantityWanted, currency);

        // Offer for token
        vm.prank(buyer);
        color.offer(listingId, quantityWanted, currency, pricePerToken, expirationTimestamp);

        vm.warp(180);

        // Accept the offer
        vm.prank(seller);
        color.acceptOffer(listingId, buyer, currency, pricePerToken);

        // Check if listing doesn't exist
        assertEq(color.getListing(0).quantity, 0);
        // Check if buyer has token
        assertEq(erc721.balanceOf(buyer), 1);
        // Check if seller has received payment (calculating minus tax, todo: enhance this to include royalties if any)
        uint256 tax = color.calculatePlatformFee(pricePerToken);
        assertEq(erc20.balanceOf(seller), 1 ether - tax);   
    }
}
