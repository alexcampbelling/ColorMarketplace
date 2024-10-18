// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RoyaltiesTests is TestHelpers {

    address public royaltyReceiver;
    uint256 public royaltyPercentage;
    uint256 public listingId;
    address native = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public override {
        super.setUp();
        royaltyReceiver = getActor(5);
        royaltyPercentage = 250; // 2.5%
    }

    function test_createListingWithRoyalties_success() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        listingParams.royaltyInfo = IColorMarketplace.RoyaltyInfo(royaltyReceiver, royaltyPercentage);

        vm.prank(seller);
        color.createListing(listingParams);

        // Assuming the first listing has ID 0
        IColorMarketplace.Listing memory listing = color.getListing(0);
        assertEq(listing.royaltyInfo.receiver, royaltyReceiver);
        assertEq(listing.royaltyInfo.percentage, royaltyPercentage);
    }

        function test_buyWithRoyalties_success() public {
        // Create listing with royalties
        test_createListingWithRoyalties_success();

        vm.warp(150); // Set the time to within the listing period

        uint256 buyoutPrice = 1 ether;
        uint256 expectedRoyalty = (buyoutPrice * royaltyPercentage) / 10000;
        uint256 expectedPlatformFee = color.calculatePlatformFee(buyoutPrice);
        uint256 expectedSellerPayout = buyoutPrice - expectedRoyalty - expectedPlatformFee;

        // Mint more tokens to the buyer and approve
        vm.prank(buyer);
        erc20.mint(buyer, buyoutPrice * 2);

        vm.prank(buyer);
        erc20.approve(address(color), buyoutPrice * 2);

        uint256 buyerBalanceBefore = erc20.balanceOf(buyer);
        uint256 sellerBalanceBefore = erc20.balanceOf(seller);
        uint256 royaltyReceiverBalanceBefore = erc20.balanceOf(royaltyReceiver);
        uint256 platformFeeRecipientBalanceBefore = erc20.balanceOf(color.getPlatformFeeRecipient());

        vm.prank(buyer);
        color.buy(0, buyer); // Assuming the listing ID is 0

        assertEq(erc20.balanceOf(buyer), buyerBalanceBefore - buyoutPrice);
        assertEq(erc20.balanceOf(seller), sellerBalanceBefore + expectedSellerPayout);
        assertEq(erc20.balanceOf(royaltyReceiver), royaltyReceiverBalanceBefore + expectedRoyalty);
        assertEq(erc20.balanceOf(color.getPlatformFeeRecipient()), platformFeeRecipientBalanceBefore + expectedPlatformFee);
    }

    function test_calculateRoyaltyFee_success() public view {
        uint256 salePrice = 1 ether;
        IColorMarketplace.RoyaltyInfo memory royaltyInfo = IColorMarketplace.RoyaltyInfo(royaltyReceiver, royaltyPercentage);

        uint256 calculatedFee = color.calculateRoyaltyFee(salePrice, royaltyInfo);
        uint256 expectedFee = (salePrice * royaltyPercentage) / 10000;

        assertEq(calculatedFee, expectedFee);
    }

    function test_royaltyDistribution_success() public view {
        uint256 salePrice = 1 ether;
        IColorMarketplace.RoyaltyInfo memory royaltyInfo = IColorMarketplace.RoyaltyInfo(royaltyReceiver, royaltyPercentage);

        (uint256 platformFee, uint256 royaltyFee, uint256 sellerPayout) = color.calculatePayoutDistribution(salePrice, royaltyInfo);

        uint256 expectedPlatformFee = color.calculatePlatformFee(salePrice);
        uint256 expectedRoyaltyFee = (salePrice * royaltyPercentage) / 10000;
        uint256 expectedSellerPayout = salePrice - expectedPlatformFee - expectedRoyaltyFee;

        assertEq(platformFee, expectedPlatformFee);
        assertEq(royaltyFee, expectedRoyaltyFee);
        assertEq(sellerPayout, expectedSellerPayout);
    }

    function test_updateListingRoyalties_success() public {
        // Create initial listing
        test_createListingWithRoyalties_success();

        vm.warp(150);

        // Update royalty info
        address newRoyaltyReceiver = getActor(6);
        uint256 newRoyaltyPercentage = 500; // 5%

        IColorMarketplace.Listing memory listing = color.getListing(0); // Assuming the listing ID is 0

        vm.prank(seller);
        color.updateListing(
            0, // Assuming the listing ID is 0
            listing.currency,
            listing.buyoutPrice,
            listing.startTime,
            listing.endTime - listing.startTime,
            IColorMarketplace.RoyaltyInfo(newRoyaltyReceiver, newRoyaltyPercentage)
        );

        IColorMarketplace.Listing memory updatedListing = color.getListing(0);
        assertEq(updatedListing.royaltyInfo.receiver, newRoyaltyReceiver);
        assertEq(updatedListing.royaltyInfo.percentage, newRoyaltyPercentage);
    }

    function test_zeroRoyalty_success() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        listingParams.royaltyInfo = IColorMarketplace.RoyaltyInfo(address(0), 0);

        vm.prank(seller);
        color.createListing(listingParams);

        vm.warp(150); // Set the time to within the listing period

        IColorMarketplace.Listing memory listing = color.getListing(0); // Assuming the listing ID is 0
        assertEq(listing.royaltyInfo.receiver, address(0));
        assertEq(listing.royaltyInfo.percentage, 0);

        // Buy the listing and check that no royalties are paid
        uint256 buyoutPrice = 1 ether;
        uint256 expectedPlatformFee = color.calculatePlatformFee(buyoutPrice);
        uint256 expectedSellerPayout = buyoutPrice - expectedPlatformFee;

        vm.prank(buyer);
        erc20.mint(buyer, buyoutPrice * 2);

        vm.prank(buyer);
        erc20.approve(address(color), buyoutPrice * 2);

        vm.prank(buyer);
        color.buy(0, buyer); // Assuming the listing ID is 0

        assertEq(erc20.balanceOf(seller), expectedSellerPayout);
        assertEq(erc20.balanceOf(color.getPlatformFeeRecipient()), expectedPlatformFee);
    }

    function test_maxRoyaltyPercentage() public {
        uint256 maxRoyaltyPercentage = 5000; // 50%
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        listingParams.royaltyInfo = IColorMarketplace.RoyaltyInfo(royaltyReceiver, maxRoyaltyPercentage);

        vm.prank(seller);
        color.createListing(listingParams);

        // Assuming this is the first listing, so it should have ID 0
        IColorMarketplace.Listing memory listing = color.getListing(0);
        assertEq(listing.royaltyInfo.percentage, maxRoyaltyPercentage);
    }

    function test_royaltyWithNativeToken() public {
        // Create listing with royalties using native token
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), native);
        listingParams.royaltyInfo = IColorMarketplace.RoyaltyInfo(royaltyReceiver, royaltyPercentage);

        vm.prank(seller);
        color.createListing(listingParams);

        vm.warp(150); // Set the time to within the listing period

        listingId = 0;
        uint256 buyoutPrice = 1 ether;
        uint256 expectedRoyalty = (buyoutPrice * royaltyPercentage) / 10000;
        uint256 expectedPlatformFee = color.calculatePlatformFee(buyoutPrice);
        uint256 expectedSellerPayout = buyoutPrice - expectedRoyalty - expectedPlatformFee;

        uint256 initialBuyerBalance = 2 ether; // Give the buyer more than needed
        vm.deal(buyer, initialBuyerBalance);

        uint256 buyerBalanceBefore = buyer.balance;
        uint256 sellerBalanceBefore = seller.balance;
        uint256 royaltyReceiverBalanceBefore = royaltyReceiver.balance;
        uint256 platformFeeRecipientBalanceBefore = color.getPlatformFeeRecipient().balance;

        vm.prank(buyer);
        color.buy{value: buyoutPrice}(listingId, buyer);

        // Check that the buyer's balance has decreased by at least the buyout price
        assertGe(buyerBalanceBefore - buyer.balance, buyoutPrice);
        assertEq(seller.balance, sellerBalanceBefore + expectedSellerPayout);
        assertEq(royaltyReceiver.balance, royaltyReceiverBalanceBefore + expectedRoyalty);
        assertEq(color.getPlatformFeeRecipient().balance, platformFeeRecipientBalanceBefore + expectedPlatformFee);
    }

    function test_royaltyCalculation_exactPercentage() public {vm.skip(true);}
    // Test if the royalty is calculated correctly for an exact percentage (e.g., 2.5%)
    function test_royaltyCalculation_roundingDown() public {vm.skip(true);}
    // Test if the royalty calculation rounds down correctly for fractional amounts
    function test_royaltyCalculation_zeroRoyalty() public {vm.skip(true);}
    // Test behavior when royalty percentage is set to 0%
    function test_royaltyDistribution_recipientAddressZero() public {vm.skip(true);}
    // Test behavior when royalty recipient address is set to address(0)
}