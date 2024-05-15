// Tests for bulk actions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

contract BulkActionsTests is TestHelpers {

    function test_bulkBuy_success() public {
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicDirectListing(0, seller, address(color));
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicDirectListing(1, seller, address(color));
        IColorMarketplace.ListingParameters memory listingParams3 = getBasicDirectListing(2, seller, address(color));

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
        IColorMarketplace.ListingParameters memory listingParams1 = getBasicDirectListing(0, seller, address(color));
        IColorMarketplace.ListingParameters memory listingParams2 = getBasicDirectListing(1, seller, address(color));
        IColorMarketplace.ListingParameters memory listingParams3 = getBasicDirectListing(2, seller, address(color));

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

    function test_bulk_list_success() public {
        
    }
    function test_bulkTransfer_success() public {vm.skip(true);}
    function test_bulkBuy_insufficientFunds_failure() public {vm.skip(true);}
    function test_bulkSell_insufficientTokens_failure() public {vm.skip(true);}
}
