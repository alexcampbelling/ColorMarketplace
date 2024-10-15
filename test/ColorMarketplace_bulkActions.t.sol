// Tests for bulk actions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

contract BulkActionsTests is TestHelpers {

    function test_bulkBuy_success() public {
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicListing(1, seller, address(color), address(erc721), address(erc20));
        IColorMarketplace.ListingParameters memory listingParams3 = getBasicListing(2, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams1);

        vm.prank(seller);
        color.createListing(listingParams2);

        vm.prank(seller);
        color.createListing(listingParams3);

        assertEq(color.getTotalListings(), 3);

        uint256 totalPrice = 1 ether;
        uint256 tax = color.calculatePlatformFee(totalPrice);

        vm.prank(buyer);
        erc20.mint(buyer, totalPrice*3);

        vm.prank(buyer);
        erc20.approve(address(color), totalPrice*3);

        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;

        address[] memory buyers = new address[](3);
        buyers[0] = buyer;
        buyers[1] = buyer;
        buyers[2] = buyer;

        address[] memory paymentTokens = new address[](3);
        paymentTokens[0] = address(erc20);
        paymentTokens[1] = address(erc20);
        paymentTokens[2] = address(erc20);

        uint256[] memory prices = new uint256[](3);
        prices[0] = totalPrice;
        prices[1] = totalPrice;
        prices[2] = totalPrice;

        vm.warp(101);

        // Bulk emmmm
        vm.prank(buyer);
        color.bulkBuy(ids, buyers);

        // Check that all listings are now invalid (closed)
        for (uint256 i = 0; i < 3; i++) {
            assertFalse(color.checkListingValid(i), "Listing should be invalid after purchase");
        }
        assertEq(erc20.balanceOf(buyer), 0);
        assertEq(erc20.balanceOf(seller), totalPrice*3 - tax*3);
        assertEq(erc721.ownerOf(0), buyer);
        assertEq(erc721.ownerOf(1), buyer);
        assertEq(erc721.ownerOf(2), buyer);
    }

    function test_bulkDelist_success() public {
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicListing(1, seller, address(color), address(erc721), address(erc20));
        IColorMarketplace.ListingParameters memory listingParams3 = getBasicListing(2, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams1);

        vm.prank(seller);
        color.createListing(listingParams2);

        vm.prank(seller);
        color.createListing(listingParams3);

        assertEq(color.getTotalListings(), 3);

        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;

        vm.prank(seller);
        color.cancelListings(ids);

        // todo alex: check this!
        // assertEq(color.getAllValidListings().length, 0);
            // Check that all listings are now invalid (closed)
        for (uint256 i = 0; i < 3; i++) {
            assertFalse(color.checkListingValid(i), "Listing should be invalid after purchase");
        }
    }

    function test_bulkBuy_nativeTokens_success() public {
        // In this test we attempt to mix native and other accepted tokens in a bulk buy

        // erc20 listing
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        
        // native token listing
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicListing(1, seller, address(color), address(erc721), NATIVE_ADDRESS);

        // Warp to correct time for basic listings
        vm.warp(150);

        vm.prank(seller);
        color.createListing(listingParams1);

        vm.prank(seller);
        color.createListing(listingParams2);

        // Now create a buyer with enough funds to buy both listings

        uint256 price = 1 ether; // hardcoded example from getBasicListing
        uint256 buyerBeforeBal = 10 ether;
        uint256 tax = color.calculatePlatformFee(price);

        // Get before values
        uint256 platformFeeRecipientBalBefore = platformFeeRecipient.balance;

        // Mint value needed for listing 1
        vm.prank(buyer);
        erc20.mint(buyer, price);

        // Approve Color to use the erc20 currency
        vm.prank(buyer);
        erc20.approve(address(color), price);

        // Give native currency more than enough for listing 2
        vm.deal(buyer, buyerBeforeBal);

        // Create data to buy both listings
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        address[] memory buyers = new address[](2);
        buyers[0] = buyer;
        buyers[1] = buyer;

        address[] memory paymentTokens = new address[](2);
        paymentTokens[0] = address(erc20);
        paymentTokens[1] = NATIVE_ADDRESS;

        uint256[] memory prices = new uint256[](2);
        prices[0] = price;
        prices[1] = price;

        // Attempt to bulkBuy
        vm.prank(buyer);
        // todo alex: now we removed some of the arguments to bulk buy and buy, lets remember to remove them from tetss too, to make them cleaner
        color.bulkBuy{value: price}(ids, buyers);

        // Assertions

        // Buyer
        assertEq(erc721.ownerOf(0), buyer);
        assertEq(erc721.ownerOf(1), buyer);
        assertEq(erc20.balanceOf(buyer), 0); // erc20
        assertEq(buyer.balance, buyerBeforeBal - price); // native currency

        // Seller
        assertEq(erc20.balanceOf(seller), price - tax);
        assertEq(seller.balance, price - tax); // todo alex: and gas? should we be checking for gas!

        // Color
        // Check that all listings are now invalid (closed)
        for (uint256 i = 0; i < 2; i++) {
            assertFalse(color.checkListingValid(i), "Listing should be invalid after cancellation");
        }
        assertEq(erc20.balanceOf(platformFeeRecipient), tax);
        assertEq(platformFeeRecipient.balance, platformFeeRecipientBalBefore + tax);
    }

    function test_bulkBuy_manyItems_success() public {
        uint256 numListings = 50; // Adjust this number to test different amounts of bulk buys
        uint256 price = 1 ether;
        uint256 totalPrice = price * numListings;
        uint256 buyerInitialBalance = totalPrice + 10 ether; // Extra balance for gas

        // Warp to correct time for basic listings
        vm.warp(150);

        // Create listings
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
        }

        // Prepare buyer
        vm.deal(buyer, buyerInitialBalance);

        // Prepare bulk buy data
        uint256[] memory ids = new uint256[](numListings);
        address[] memory buyers = new address[](numListings);
        address[] memory paymentTokens = new address[](numListings);
        uint256[] memory prices = new uint256[](numListings);

        for (uint256 i = 0; i < numListings; i++) {
            ids[i] = i;
            buyers[i] = buyer;
            paymentTokens[i] = NATIVE_ADDRESS;
            prices[i] = price;
        }

        // Attempt bulk buy
        vm.prank(buyer);
        color.bulkBuy{value: totalPrice}(ids, buyers);

        // Assertions
        for (uint256 i = 0; i < numListings; i++) {
            assertEq(erc721.ownerOf(i), buyer);
        }
        assertEq(buyer.balance, buyerInitialBalance - totalPrice);
        for (uint256 i = 0; i < numListings; i++) {
            assertFalse(color.checkListingValid(i), "Listing should be invalid after cancellation");
        }
    }

    function test_bulkBuy_insufficientFunds_failure() public {vm.skip(true);}
    function test_bulkSell_insufficientTokens_failure() public {vm.skip(true);}

    // todo alex: make test for bulk listing

    function test_bulkBuy_invalidMsgValue() public {
        uint256 numListings = 3;
        uint256 price = 1 ether;

        // Set the block timestamp to a value after the listing start time
        vm.warp(150);

        // Create listings
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
        }

        // Prepare bulk buy data
        uint256[] memory ids = new uint256[](numListings);
        address[] memory buyers = new address[](numListings);

        for (uint256 i = 0; i < numListings; i++) {
            ids[i] = i;
            buyers[i] = buyer;
        }

        uint256 totalExpectedValue = price * numListings;
        uint256 invalidValue = totalExpectedValue - 1; // Send 1 wei less than required

        // Attempt bulk buy with incorrect msg.value
        vm.prank(buyer);
        vm.deal(buyer, invalidValue);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InvalidMsgValue.selector, invalidValue, totalExpectedValue));
        color.bulkBuy{value: invalidValue}(ids, buyers);
    }
}
