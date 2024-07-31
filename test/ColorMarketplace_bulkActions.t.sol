// Tests for bulk actions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

contract BulkActionsTests is TestHelpers {

    function test_bulkBuy_success() public {
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20), false);
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicDirectListing(1, seller, address(color), address(erc721), address(erc20), false);
        IColorMarketplace.ListingParameters memory listingParams3 = getBasicDirectListing(2, seller, address(color), address(erc721), address(erc20), false);

        vm.prank(seller);
        color.createListing(listingParams1);

        vm.prank(seller);
        color.createListing(listingParams2);

        vm.prank(seller);
        color.createListing(listingParams3);

        assertEq(color.totalListings(), 3);

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

        uint256[] memory quantities = new uint256[](3);
        quantities[0] = 1;
        quantities[1] = 1;
        quantities[2] = 1;

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
        color.bulkBuy(ids, buyers, quantities, paymentTokens, prices);

        assertEq(color.getAllValidListings().length, 0);
        assertEq(erc20.balanceOf(buyer), 0);
        assertEq(erc20.balanceOf(seller), totalPrice*3 - tax*3);
        assertEq(erc721.ownerOf(0), buyer);
        assertEq(erc721.ownerOf(1), buyer);
        assertEq(erc721.ownerOf(2), buyer);
    }

    function test_bulkDelist_success() public {
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20), false);
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicDirectListing(1, seller, address(color), address(erc721), address(erc20), false);
        IColorMarketplace.ListingParameters memory listingParams3 = getBasicDirectListing(2, seller, address(color), address(erc721), address(erc20), false);

        vm.prank(seller);
        color.createListing(listingParams1);

        vm.prank(seller);
        color.createListing(listingParams2);

        vm.prank(seller);
        color.createListing(listingParams3);

        assertEq(color.totalListings(), 3);

        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;

        vm.prank(seller);
        color.cancelDirectListings(ids);

        assertEq(color.getAllValidListings().length, 0);
    }

    function test_bulkBuy_nativeTokens_success() public {
        // In this test we attempt to mix native and other accepted tokens in a bulk buy

        // erc20 listing
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicDirectListing(0, seller, address(color), address(erc721), address(erc20), false);
        
        // native token listing
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicDirectListing(1, seller, address(color), address(erc721), NATIVE_ADDRESS, false);

        vm.prank(seller);
        color.createListing(listingParams1);

        vm.prank(seller);
        color.createListing(listingParams2);

        // Now create a buyer with enough funds to buy both listings

        uint256 price = 1 ether; // hardcoded example from getBasicDirectListing
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

        uint256[] memory quantities = new uint256[](2);
        quantities[0] = 1;
        quantities[1] = 1;

        address[] memory paymentTokens = new address[](2);
        paymentTokens[0] = address(erc20);
        paymentTokens[1] = NATIVE_ADDRESS;

        uint256[] memory prices = new uint256[](2);
        prices[0] = price;
        prices[1] = price;

        // Attempt to bulkBuy
        vm.prank(buyer);
        color.bulkBuy{value: price}(ids, buyers, quantities, paymentTokens, prices);

        // Assertions

        // Buyer
        assertEq(erc721.ownerOf(0), buyer);
        assertEq(erc721.ownerOf(1), buyer);
        assertEq(erc20.balanceOf(buyer), 0); // erc20
        assertEq(buyer.balance, buyerBeforeBal - price); // native currency

        // Seller
        assertEq(erc20.balanceOf(seller), price - tax);
        assertEq(seller.balance, price - tax); // and gas?

        // Color
        assertEq(color.getAllValidListings().length, 0);
        assertEq(erc20.balanceOf(platformFeeRecipient), tax);
        assertEq(platformFeeRecipient.balance, platformFeeRecipientBalBefore + tax);
    }
    function test_bulkBuy_erc721AndErc1155_success() public {
        // In this test we attempt to mix ERC721 and ERC1155 tokens in a bulk buy

        // erc721 listing
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicDirectListing(0, seller, address(color), address(erc721), NATIVE_ADDRESS, false);
        
        // erc1155 listing
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicDirectListing(1, seller, address(color), address(erc1155), NATIVE_ADDRESS, true);

        vm.prank(seller);
        color.createListing(listingParams1);

        vm.prank(seller);
        color.createListing(listingParams2);

        // Now create a buyer with enough funds to buy both listings

        uint256 price = 1 ether; // hardcoded example from getBasicDirectListing
        uint256 buyerBeforeBal = 10 ether;
        uint256 tax = color.calculatePlatformFee(price);

        // Get before values
        uint256 platformFeeRecipientBalBefore = platformFeeRecipient.balance;

        // Give native currency more than enough for both listings
        vm.deal(buyer, buyerBeforeBal);

        // Create data to buy both listings
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        address[] memory buyers = new address[](2);
        buyers[0] = buyer;
        buyers[1] = buyer;

        uint256[] memory quantities = new uint256[](2);
        quantities[0] = 1;
        quantities[1] = 1;

        address[] memory paymentTokens = new address[](2);
        paymentTokens[0] = NATIVE_ADDRESS;
        paymentTokens[1] = NATIVE_ADDRESS;

        uint256[] memory prices = new uint256[](2);
        prices[0] = price;
        prices[1] = price;

        // Attempt to bulkBuy
        vm.prank(buyer);
        color.bulkBuy{value: 2 * price}(ids, buyers, quantities, paymentTokens, prices);

        // Assertions

        // Buyer
        assertEq(erc721.ownerOf(0), buyer);
        assertEq(erc1155.balanceOf(buyer, 1), 1);
        assertEq(buyer.balance, buyerBeforeBal - 2 * price); // native currency

        // Seller
        assertEq(seller.balance, 2 * (price - tax)); // and gas?

        // Color
        assertEq(color.getAllValidListings().length, 0);
        assertEq(platformFeeRecipient.balance, platformFeeRecipientBalBefore + 2 * tax);
    }

    function test_bulkBuy_directAndAuction_success() public {
        // Hardcoded values for auction and direct listings
        uint256 directListingId = 0;
        uint256 auctionListingId = 1;
        uint256 erc721TokenId1 = 0; // Token ID for the first ERC721 token
        uint256 erc721TokenId2 = 1; // Token ID for the second ERC721 token
        uint256 directListingPrice = 5 ether;
        uint256 auctionBuyoutPrice = 10 ether;

        // Mint 2 ERC721 tokens for seller and approve marketplace
        _setupERC721BalanceForSeller(seller, 2); // Mint 2 ERC721 tokens for the seller
        vm.prank(seller);
        erc721.setApprovalForAll(address(color), true);

        // List ERC721 token (Direct Listing)
        IColorMarketplace.ListingParameters memory directListingParams = IColorMarketplace.ListingParameters(
            address(erc721), erc721TokenId1, block.timestamp, 0, 1, NATIVE_ADDRESS, directListingPrice, directListingPrice, IColorMarketplace.ListingType.Direct
        );
        vm.prank(seller);
        color.createListing(directListingParams);

        // List ERC721 token (Auction Listing)
        IColorMarketplace.ListingParameters memory auctionListingParams = IColorMarketplace.ListingParameters(
            address(erc721), erc721TokenId2, block.timestamp, block.timestamp + 1 days, 1, NATIVE_ADDRESS, 0, auctionBuyoutPrice, IColorMarketplace.ListingType.Auction
        );
        vm.prank(seller);
        color.createListing(auctionListingParams);

        // Set up the buyer with enough funds
        uint256 totalBuyoutPrice = directListingPrice + auctionBuyoutPrice;
        uint256 buyerBeforeBal = 30 ether;
        vm.deal(buyer, buyerBeforeBal);

        // Calculate platform fees
        uint256 directTax = color.calculatePlatformFee(directListingPrice);
        uint256 auctionTax = color.calculatePlatformFee(auctionBuyoutPrice);

        // Create data to buy both listings
        uint256[] memory ids = new uint256[](2);
        ids[0] = directListingId;
        ids[1] = auctionListingId;

        address[] memory buyers = new address[](2);
        buyers[0] = buyer;
        buyers[1] = buyer;

        uint256[] memory quantities = new uint256[](2);
        quantities[0] = 1; // Quantity for ERC721 is always 1
        quantities[1] = 1; // Quantity for ERC721 is always 1

        address[] memory paymentTokens = new address[](2);
        paymentTokens[0] = NATIVE_ADDRESS;
        paymentTokens[1] = NATIVE_ADDRESS;

        uint256[] memory prices = new uint256[](2);
        prices[0] = directListingPrice;
        prices[1] = auctionBuyoutPrice;

        // Attempt to bulkBuy
        vm.prank(buyer);
        color.bulkBuy{value: totalBuyoutPrice}(ids, buyers, quantities, paymentTokens, prices);

        // Close the auction so the seller gets total compensation - fees
        vm.warp(21001); // Must warp to next block to allow seller to claim
        vm.prank(seller);
        color.closeAuction(auctionListingId, seller);

        // Assertions
        assertEq(erc721.ownerOf(erc721TokenId1), buyer);
        assertEq(erc721.ownerOf(erc721TokenId2), buyer);
        assertEq(buyer.balance, buyerBeforeBal - totalBuyoutPrice); // native currency
        assertEq(seller.balance, directListingPrice - directTax + auctionBuyoutPrice - auctionTax);
        assertEq(color.getAllValidListings().length, 0);
        assertEq(platformFeeRecipient.balance, directTax + auctionTax);
    }

    function test_bulkBuy_erc1155_success() public {vm.skip(true);}

    function test_bulkBuy_erc1155_notFullAmount_success() public {vm.skip(true);}

    function test_bulkBuy_insufficientFunds_failure() public {vm.skip(true);}
    function test_bulkSell_insufficientTokens_failure() public {vm.skip(true);}
}
