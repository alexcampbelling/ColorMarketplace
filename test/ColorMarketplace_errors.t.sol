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
        vm.expectRevert(abi.encodeWithSelector(
            IColorMarketplace.TokenNotAccepted.selector,
            address(token)
        ));

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
        vm.expectRevert(abi.encodeWithSelector(
            IColorMarketplace.TokenNotAccepted.selector,
            address(mockToken)
        ));

        vm.prank(seller);
        color.updateListing(
            0,
            address(mockToken),
            listingParams.buyoutPrice,
            listingParams.startTime,
            listingParams.secondsUntilEndTime
        );
    }

  function test_createListing_InvalidStartTime_error() public {

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
        vm.expectRevert(abi.encodeWithSelector(
            IColorMarketplace.InvalidStartTime.selector,
            twoHoursAgo,
            currentTime
        ));

        vm.warp(currentTime);

        // Attempt to create the listing
        vm.prank(seller);
        color.createListing(listingParams);
    }

    function test_notListingOwner_error() public {
        uint256 listingId = createAndApproveListing();

        // Attempt to update the listing as a non-owner
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(
            IColorMarketplace.NotListingOwner.selector,
            seller,
            buyer
        ));
        color.updateListing(
            listingId,
            address(erc20),
            2 ether,
            block.timestamp,
            1 days
        );
    }

    function test_listingDoesNotExist_error() public {
        uint256 nonExistentListingId = 999;

        vm.expectRevert(abi.encodeWithSelector(
            IColorMarketplace.ListingDoesNotExist.selector,
            nonExistentListingId
        ));
        color.getListing(nonExistentListingId);
    }

    function test_invalidStartTime_error() public {
        // Create a listing with a start time in the past
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        
        // Ensure the current time is at least 2 hours in the future
        uint256 currentTime = block.timestamp + 3 hours;
        vm.warp(currentTime);

        uint256 invalidStartTime = currentTime - 2 hours;
        listingParams.startTime = invalidStartTime;

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(
            IColorMarketplace.InvalidStartTime.selector,
            listingParams.startTime,
            currentTime
        ));
        color.createListing(listingParams);
    }

    function test_tokenNotValidOrApproved_error() public {
        // Mint token for seller
        _setupERC721BalanceForSeller(seller, 1);

        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));

        // Ensure the marketplace is not approved for all
        vm.prank(seller);
        erc721.setApprovalForAll(address(color), false);

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(
            IColorMarketplace.TokenNotValidOrApproved.selector,
            address(erc721),
            0,
            seller
        ));
        color.createListing(listingParams);
    }

    function test_invalidMsgValue_error() public {
        // Use NATIVE_ADDRESS for the currency
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), NATIVE_ADDRESS);
        
        vm.prank(seller);
        color.createListing(listingParams);

        uint256 listingId = 0;
        address buyFor = address(buyer);
        uint256 totalPrice = 1 ether;

        // Ensure the listing is active
        vm.warp(listingParams.startTime + 1);

        // Give the buyer some ETH
        vm.deal(buyer, 2 ether);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InvalidMsgValue.selector, totalPrice - 1, totalPrice));
        color.buy{value: totalPrice - 1}(listingId, buyFor);
    }

    function test_insufficientBalanceOrAllowance_error() public {
        uint256 listingId = createAndApproveListing();
        IColorMarketplace.Listing memory listing = color.getListing(listingId);

        // Ensure the listing is active
        vm.warp(listing.startTime);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InsufficientBalanceOrAllowance.selector, true, true));
        color.buy(listingId, buyer);
    }

    function test_offerExpired_error() public {
        uint256 listingId = createAndApproveListing();
        IColorMarketplace.Listing memory listing = color.getListing(listingId);
        
        // Ensure the listing is active
        vm.warp(listing.startTime);
        
        uint256 offerPrice = 0.5 ether;
        uint256 expirationTime = block.timestamp + 1 hours;

        // Give the buyer enough balance and allowance
        erc20.mint(buyer, offerPrice);
        vm.prank(buyer);
        erc20.approve(address(color), offerPrice);

        // Create the offer
        vm.prank(buyer);
        color.offer(listingId, offerPrice, expirationTime);

        // Move time forward past the expiration
        vm.warp(expirationTime + 1);

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.OfferExpired.selector, expirationTime, block.timestamp));
        color.acceptOffer(listingId, buyer);
    }

    function test_inactiveListing_error() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        listingParams.startTime = block.timestamp + 1 hours; // Set start time in the future

        vm.prank(seller);
        color.createListing(listingParams);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InactiveListing.selector, listingParams.startTime, listingParams.startTime + listingParams.secondsUntilEndTime, block.timestamp));
        color.buy(0, buyer);
    }

    function test_valueNotNeeded_error() public {
        uint256 listingId = createAndApproveListing();
        IColorMarketplace.Listing memory listing = color.getListing(listingId);

        // Give the buyer some ETH
        vm.deal(buyer, 2 ether);
        
        // Ensure the listing is active
        vm.warp(listing.startTime + 1);

        // Give the buyer enough balance for the ERC20 token
        erc20.mint(buyer, listing.buyoutPrice);
        vm.prank(buyer);
        erc20.approve(address(color), listing.buyoutPrice);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.ValueNotNeeded.selector, 1 ether));
        color.buy{value: 1 ether}(listingId, buyer); // Sending ETH for an ERC20 listing
    }
    function test_invalidPlatformFeeBps_error() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InvalidPlatformFeeBps.selector));
        color.setPlatformFeeInfo(address(this), 10001); // 100.01% fee, which is invalid
    }

    function test_invalidERC20_error() public {
        address invalidERC20 = address(0x123); // An address that's not a valid ERC20 token

        // Deploy a mock contract at this address that doesn't implement ERC20
        vm.etch(invalidERC20, hex"00");

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InvalidERC20.selector, invalidERC20));
        color.erc20WhiteListAdd(invalidERC20);
    }

    function test_invalidERC20_nonContract_error() public {
        address nonContractAddress = address(0x456); // A regular address, not a contract

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InvalidERC20.selector, nonContractAddress));
        color.erc20WhiteListAdd(nonContractAddress);
    }

    function test_listingNotOpen_error() public {
        uint256 listingId = createAndApproveListing();
        
        // Cancel the listing
        vm.prank(seller);
        color.cancelListing(listingId);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.ListingNotOpen.selector, listingId, IColorMarketplace.ListingStatus.Cancelled));
        color.buy(listingId, buyer);
    }

    function test_arrayLengthMismatch_error() public {
        uint256[] memory listingIds = new uint256[](2);
        listingIds[0] = 0;
        listingIds[1] = 1;

        address[] memory buyers = new address[](1);
        buyers[0] = buyer;

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.ArrayLengthMismatch.selector, listingIds.length, buyers.length));
        color.bulkBuy(listingIds, buyers);
    }

    function test_invalidOfferPrice_error() public {
        uint256 listingId = createAndApproveListing();

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InvalidOfferPrice.selector));
        color.offer(listingId, 0, block.timestamp + 1 hours); // Offer price of 0 is invalid
    }

    function test_offerDoesNotExist_error() public {
        uint256 listingId = createAndApproveListing();

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.OfferDoesNotExist.selector, listingId, buyer));
        color.acceptOffer(listingId, buyer); // No offer exists for this buyer
    }

    function test_cancelOffer_offerDoesNotExist() public {
        uint256 listingId = createAndApproveListing();
        
        // Try to cancel a non-existent offer
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.OfferDoesNotExist.selector, listingId, buyer));
        color.cancelOffer(listingId);
    }

    function test_invalidFeeRecipient_error() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.InvalidFeeRecipient.selector));
        color.setPlatformFeeInfo(address(0), 250); // address(0) is an invalid fee recipient
    }

    function test_startTimeTooFarInFuture_error() public {
        IColorMarketplace.ListingParameters memory listingParams = getBasicListing(0, seller, address(color), address(erc721), address(erc20));
        listingParams.startTime = block.timestamp + 366 days; // More than a year in the future

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(IColorMarketplace.StartTimeTooFarInFuture.selector, listingParams.startTime, block.timestamp + 365 days));
        color.createListing(listingParams);
    }

}
