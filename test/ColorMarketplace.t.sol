// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseTest } from "./utils/BaseTest.sol";
import { console } from "forge-std/Test.sol";
import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";

contract ColorMarketplaceTest is BaseTest {

    ColorMarketplace public color;

    address public seller;
    address public buyer;

    function setUp() public override {
        super.setUp();
        seller = getActor(1);
        buyer = getActor(2);
        color = new ColorMarketplace(address(0), address(0));
    }

    function _setupERC721BalanceForSeller(address _seller, uint256 _numOfTokens) private {
        erc721.mint(_seller, _numOfTokens);
    }

    function test_listERC721_direct() public {
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
        vm.prank(seller);
        erc721.setApprovalForAll(address(color), true);

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
        color.createListing(listingParams);

        // Check if listing count incremented
        assertEq(color.totalListings(), 1);
    }

    function test_full_buy_process() public {
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
        vm.prank(seller);
        erc721.setApprovalForAll(address(color), true);

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

        // Check if seller has received payment
        assertEq(erc20.balanceOf(seller), 1 ether);

    }

    function test_auction_bid_accept() public {vm.skip(true);}

    function test_auction_bid_timeEnd() public {vm.skip(true);}

    function test_auction_no_bids() public {vm.skip(true);}

    function test_delist_then_attempt_buy() public {vm.skip(true);}
}
