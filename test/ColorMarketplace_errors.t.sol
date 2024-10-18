// Tests to check reverts and errors

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";
import "forge-std/console.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";

contract ErrorsTests is TestHelpers {

    function test_createListing_TokenNotAccepted_error() public {
        // Make spoof token that's not accepted
        MockERC20 token = new MockERC20();

        // Make listing
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        listingParams.currency = address(token);

        // Expect the error
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.TokenNotAccepted.selector)
        );

        vm.prank(seller);
        color.createListing(listingParams);
    }

    function test_updateListing_TokenNotAccepted_error() public {
        
        // Make listing
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));

        vm.prank(seller);
        color.createListing(listingParams);

        // Make spoof token that's not accepted
        MockERC20 mockToken = new MockERC20();
        listingParams.currency = address(mockToken);

        // Expect the error
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.TokenNotAccepted.selector)
        );

        vm.prank(seller);
        color.updateListing(
            0,
            address(mockToken),
            listingParams.buyoutPrice,
            listingParams.startTime,
            listingParams.secondsUntilEndTime,
            IColorMarketplace.RoyaltyInfo(address(0), 0)
        );
    }

  function test_createListing_InvalidStartTime_error() public {
        // Setup
        console.log("block.timestamp before warp:", block.timestamp);


        // Create a listing with a start time more than 1 hour in the past
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(
            0, // tokenId 
            seller, 
            address(color), 
            address(erc721), 
            NATIVE_ADDRESS
        );

        uint256 currentTime = block.timestamp + 100000000000000; // Use a large buffer
        uint256 twoHours = 2 hours;
        uint256 twoHoursAgo = currentTime - twoHours;

        // Directly set the start time to a value in the past
        listingParams.startTime = twoHoursAgo;

        // Expect the error
        vm.expectRevert(
            abi.encodeWithSelector(IColorMarketplace.InvalidStartTime.selector)
        );

        console.log("Attempting to create the listing");

        vm.warp(currentTime);

        // Attempt to create the listing
        vm.prank(seller);
        color.createListing(listingParams);
    }

    function test_notListingOwner_error() public {vm.skip(true);}
    function test_doesNotExist_error() public {vm.skip(true);}
    function test_tokenNotSupported_error() public {vm.skip(true);}
    function test_invalidStartTime_error() public {vm.skip(true);}
    function test_tokenNotValidOrApproved_error() public {vm.skip(true);}
    function test_invalidPrice_error() public {vm.skip(true);}
    function test_listingAlreadyStarted_error() public {vm.skip(true);}
    function test_invalidTotalPrice_error() public {vm.skip(true);}
    function test_invalidTokenAmount_error() public {vm.skip(true);}
    function test_notWithinSaleWindow_error() public {vm.skip(true);}
    function test_invalidMsgValue_error() public {vm.skip(true);}
    function test_insufficientBalanceOrAllowance_error() public {vm.skip(true);}
    function test_offerExpired_error() public {vm.skip(true);}
    function test_inactiveListing_error() public {vm.skip(true);}
    function test_invalidCurrency_error() public {vm.skip(true);}
    function test_zeroAmountBid_error() public {vm.skip(true);}
    function test_valueNotNeeded_error() public {vm.skip(true);}
    function test_notWinningBid_error() public {vm.skip(true);}
    function test_invalidPlatformFeeBps_error() public {vm.skip(true);}
    function test_invalidBPS_error() public {vm.skip(true);}
    function test_insufficientTokensInListing_error() public {vm.skip(true);}
    function test_noTokensInListing_error() public {vm.skip(true);}
    function test_notListingCreator_error() public {vm.skip(true);}
}
