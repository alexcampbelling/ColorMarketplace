// Tests to check reverts and errors

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";

contract ErrorsTests is TestHelpers {

    function test_createListing_TokenNotAccepted_error() public {
        // Make spoof token that's not accepted
        MockERC20 token = new MockERC20();

        // Make listing
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));
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
        IColorMarketplace.ListingParameters memory listingParams = getBasicDirectListing(0, seller, address(color));

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
            listingParams.quantityToList,
            address(mockToken),
            listingParams.reservePricePerToken,
            listingParams.buyoutPricePerToken,
            listingParams.startTime,
            listingParams.secondsUntilEndTime
        );
    }

    function test_notListingOwner_error() public {vm.skip(true);}
    function test_doesNotExist_error() public {vm.skip(true);}
    function test_tokenNotSupported_error() public {vm.skip(true);}
    function test_invalidQuantity_error() public {vm.skip(true);}
    function test_invalidStartTime_error() public {vm.skip(true);}
    function test_tokenNotValidOrApproved_error() public {vm.skip(true);}
    function test_invalidPrice_error() public {vm.skip(true);}
    function test_listingAlreadyStarted_error() public {vm.skip(true);}
    function test_notDirectListing_error() public {vm.skip(true);}
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
    function test_auctionNotEnded_error() public {vm.skip(true);}
    function test_invalidPlatformFeeBps_error() public {vm.skip(true);}
    function test_invalidBPS_error() public {vm.skip(true);}
    function test_insufficientTokensInListing_error() public {vm.skip(true);}
    function test_noTokensInListing_error() public {vm.skip(true);}
    function test_notAnAuction_error() public {vm.skip(true);}
    function test_notListingCreator_error() public {vm.skip(true);}
}
