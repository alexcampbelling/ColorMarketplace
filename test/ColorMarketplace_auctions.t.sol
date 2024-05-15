// Tests for auctions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

/* Testing - todo: remove this on deploys */
import { console } from "forge-std/Test.sol";

contract AuctionsTests is TestHelpers {

    function createBasicAuction() private returns (IColorMarketplace.ListingParameters memory) {
        IColorMarketplace.ListingParameters memory listingParams = getBasicAuctionListing();
        vm.prank(seller);
        vm.expectEmit();
        emit IColorMarketplace.ListingAdded(
            0, 
            address(erc721), 
            seller, 
            IColorMarketplace.Listing({ 
                listingId: 0, 
                tokenOwner: 0x0000000000000000000000000000000000050001, 
                assetContract: 0x2e234DAe75C793f67A35089C9d99245E1C58470b, 
                tokenId: 0, 
                startTime: 100, 
                endTime: 300, 
                quantity: 1, 
                currency: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, 
                reservePricePerToken: 1000000000000000000, 
                buyoutPricePerToken: 2000000000000000000, 
                tokenType: IColorMarketplace.TokenType.ERC721, 
                listingType: IColorMarketplace.ListingType.Auction 
            })
        );
        color.createListing(listingParams);
        return listingParams;
    }

    function createBasicAuctionEther() private returns (IColorMarketplace.ListingParameters memory) {
        // Sample listing parameters.
        address assetContract = address(erc721);
        uint256 tokenId = 0;
        uint256 startTime = 100;
        uint256 secondsUntilEndTime = 200;
        uint256 quantityToList = 1;
        address currency = NATIVE_ADDRESS;
        uint256 reservePricePerToken = 1 ether;
        uint256 buyoutPricePerToken = 2 ether;
        IColorMarketplace.ListingType listingType = IColorMarketplace.ListingType.Auction;

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
        return listingParams;
    }

    function give_erc20(address to, uint256 amount) private {
        erc20.mint(to, amount);

        vm.prank(to);
        erc20.approve(address(color), amount);
    }

    function test_createAuction_success() public {
        createBasicAuction();
        assertEq(color.totalListings(), 1);
    }

    // List token as auction, bidder bids for price above min and below buyout, acc
    function test_bidOnAuction_erc20_buyer_closes_success() public {
        IColorMarketplace.ListingParameters memory listingParams = createBasicAuction();
        uint256 listingId = 0;
        uint256 offerPrice = listingParams.reservePricePerToken+ 0.5 ether;

        uint256 buyerErc20Balance = 100 ether;
        give_erc20(buyer, buyerErc20Balance);

        // Warp to middle of buying time period
        vm.warp(150);

        vm.prank(buyer);
        color.offer(listingId, listingParams.quantityToList, listingParams.currency, offerPrice, 290);
        
        // Warp to after auction
        // Must take into account the time buffer (15 minutes)
        vm.warp(2201);

        // Bidder closes auction to retrieve the token
        vm.expectEmit(true, true, true, true, address(color));
        emit IColorMarketplace.AuctionClosed(
            listingId, 
            seller, 
            false,
            seller,
            buyer
        );

        vm.prank(seller);
        color.closeAuction(listingId, seller);

        vm.warp(2202);
        
        vm.expectEmit(true, true, true, true, address(color));
        emit IColorMarketplace.AuctionClosed(
            listingId, 
            buyer, 
            false,
            seller,
            buyer
        );

        vm.prank(buyer);
        color.closeAuction(listingId, buyer);
        
        // Check if listing doesn't exist
        assertEq(color.getListing(0).quantity, 0);
        // Check if buyer has token
        assertEq(erc721.balanceOf(buyer), 1);
        assertEq(erc20.balanceOf(buyer), buyerErc20Balance - offerPrice);
        // Check if seller has received payment (calculating minus tax, todo: enhance this to include royalties if any)
        uint256 tax = color.calculatePlatformFee(offerPrice);
        assertEq(erc20.balanceOf(seller), offerPrice - tax);
    }

    function test_nobids_seller_closes_success() public {
        // Create auction
        createBasicAuction();

        // Check tokens in escrow
        assertEq(erc721.balanceOf(address(color)), 1);

        // Check seller doesn't have token
        assertEq(erc721.balanceOf(seller), 0);

        // Close auction
        vm.expectEmit(true, true, true, true, address(color));
        emit IColorMarketplace.AuctionClosed(
            0, 
            seller, 
            true,
            seller,
            address(0)
        );
        vm.prank(seller);
        color.closeAuction(0, seller);

        // Check tokens not on market
        assertEq(erc721.balanceOf(address(color)), 0);

        // Check seller doesn't have token
        assertEq(erc721.balanceOf(seller), 1);
    }

    // todo: finish this native token attempt
    function test_bidOnAuction_native_success() public {
        // Create auction with native token
        IColorMarketplace.ListingParameters memory listingParams = createBasicAuctionEther();
        uint256 listingId = 0;

        // todo: check listing exists


        // Place bid
        uint256 buyerBeforeBal = 10 ether;
        vm.deal(buyer, buyerBeforeBal);

        uint256 offerAmount = 1.5 ether;

        // Warp into listing time frame
        vm.warp(150);

        vm.prank(buyer);
        color.offer{value: offerAmount}(listingId, listingParams.quantityToList, listingParams.currency, offerAmount, 290);
        
        // todo: check winning bid

        // Check listing and bid state
        assertEq(erc721.ownerOf(listingParams.tokenId), address(color));
        assertEq(weth.balanceOf(address(color)), offerAmount);
        assertEq(buyer.balance, buyerBeforeBal - offerAmount);

        // Seller accepts offer
        vm.warp(21000);
        vm.prank(seller);
        color.closeAuction(listingId, seller);

        // THE SELLER AND BUYER CAN'T CLAIM IN THE SAME BLOCK.TIMESTAMP OMG
        vm.warp(22000);

        // Check after seller closes auction state

        // Nothing in escrow
        assertEq(weth.balanceOf(address(color)), 0 ether);

        // Seller is paid correct amount after tax
        uint256 listingAmountPostTaxt = offerAmount - color.calculatePlatformFee(offerAmount);
        assertEq(seller.balance, listingAmountPostTaxt);

        // Buyer is less the offer amount
        assertEq(buyer.balance, buyerBeforeBal - offerAmount);

        // Buyer must also close the auction to claim the token

        vm.prank(buyer);
        color.closeAuction(listingId, buyer);

        // Buyer has the bought token
        assertEq(erc721.ownerOf(listingParams.tokenId), address(buyer));
    }
    
    // List auction, bid once, another bidder bids over, check first bidder got returned amonut and can bid again
    function test_outbidding_erc20_success() public {
        // List auction
        IColorMarketplace.ListingParameters memory listingParams = createBasicAuction();
        uint256 listingId = 0;

        // Set up
        address buyer1 = getActor(11);
        address buyer2 = getActor(22);

        uint256 buyersErc20Balance = 10 ether;

        give_erc20(buyer1, buyersErc20Balance);
        give_erc20(buyer2, buyersErc20Balance);

        uint256 offerPrice1 = listingParams.reservePricePerToken + 0.1 ether;
        uint256 offerPrice2 = offerPrice1 + 0.1 ether;

        // Warp to auction start
        vm.warp(101);

        // First bidder bids
        vm.prank(buyer1);
        color.offer(listingId, listingParams.quantityToList, listingParams.currency, offerPrice1, 290);

        // Check the current winning bid is by the first bidder
        IColorMarketplace.Offer memory currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer1);

        // Check that market has the offer in escrow
        assertEq(erc20.balanceOf(address(color)), offerPrice1);
        
        // Second bidder bids
        vm.prank(buyer2);
        color.offer(listingId, listingParams.quantityToList, listingParams.currency, offerPrice2, 290);

        // Check the current winning bid is by the second bidder
        currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer2);

        // Check that market has the offer in escrow
        assertEq(erc20.balanceOf(address(color)), offerPrice2);

        // Check that buyer1 was refunded
        assertEq(erc20.balanceOf(buyer1), buyersErc20Balance);

        // Warp to end of auction
        vm.warp(21000);

        // Check that buyer2 can close the auction
        vm.prank(buyer2);
        color.closeAuction(listingId, buyer2);

        // Check that buyer2 has the token and is less the funds
        assertEq(erc721.balanceOf(buyer2), 1);
        assertEq(erc20.balanceOf(buyer2), buyersErc20Balance - offerPrice2);

        // Check that seller doesn't have funds before claiming themselves
        assertEq(erc20.balanceOf(seller), 0);
        assertEq(erc20.balanceOf(address(color)), offerPrice2);

        // Seller claims the funds
        vm.warp(21001); // Must warp to next block to allow seller to claim
        vm.prank(seller);
        color.closeAuction(listingId, seller);

        // Check that seller has the funds
        assertEq(erc20.balanceOf(seller), offerPrice2 - color.calculatePlatformFee(offerPrice2));

        // Check that the market doesnt have anything in escrow
        assertEq(erc721.balanceOf(address(color)), 0);
        assertEq(erc20.balanceOf(address(color)), 0);
    }

    function test_outbidding_native_success() public {
        // List auction
        IColorMarketplace.ListingParameters memory listingParams = createBasicAuctionEther();
        uint256 listingId = 0;

        // Set up
        address buyer1 = getActor(11);
        address buyer2 = getActor(22);

        uint256 buyersNativeBalance = 10 ether;

        vm.deal(buyer1, buyersNativeBalance);
        vm.deal(buyer2, buyersNativeBalance);

        uint256 offerPrice1 = listingParams.reservePricePerToken + 0.1 ether;
        uint256 offerPrice2 = offerPrice1 + 0.1 ether;

        // Warp to auction start
        vm.warp(101);

        // First bidder bids
        vm.prank(buyer1);
        color.offer{value: offerPrice1}(listingId, listingParams.quantityToList, listingParams.currency, offerPrice1, 290);

        // Check the current winning bid is by the first bidder
        IColorMarketplace.Offer memory currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer1);

        // Check that market has the offer in escrow
        assertEq(weth.balanceOf(address(color)), offerPrice1);
        
        // Second bidder bids
        vm.prank(buyer2);
        color.offer{value: offerPrice2}(listingId, listingParams.quantityToList, listingParams.currency, offerPrice2, 290);
        
        // Check the current winning bid is by the second bidder
        currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer2);

        // Check that market has the offer in escrow
        assertEq(weth.balanceOf(address(color)), offerPrice2);

        // Check that buyer1 was refunded
        assertEq(buyer1.balance, buyersNativeBalance);

        // Warp to end of auction
        vm.warp(21000);

        // Check that buyer2 can close the auction
        vm.prank(buyer2);
        color.closeAuction(listingId, buyer2);

        // Check that buyer2 has the token and is less the funds
        assertEq(erc721.balanceOf(buyer2), 1);
        assertEq(buyer2.balance, buyersNativeBalance - offerPrice2);

        // Check that seller doesn't have funds before claiming themselves
        assertEq(seller.balance, 0);
        assertEq(weth.balanceOf(address(color)), offerPrice2);

        // Seller claims the funds
        vm.warp(21001); // Must warp to next block to allow seller to claim
        vm.prank(seller);
        color.closeAuction(listingId, seller);

        // Check that seller has the funds
        assertEq(seller.balance, offerPrice2 - color.calculatePlatformFee(offerPrice2));

        // Check that the market doesnt have anything in escrow
        assertEq(erc721.balanceOf(address(color)), 0);
        assertEq(weth.balanceOf(address(color)), 0);
    }

    // Bidder outbids self
    function test_outBid_self_native_success() public {
        // List auction
        IColorMarketplace.ListingParameters memory listingParams = createBasicAuctionEther();
        uint256 listingId = 0;

        // Set up
        address buyer1 = getActor(11);
        address buyer2 = buyer1; // This is the only difference from "test_outbidding_native_success"

        uint256 buyersNativeBalance = 10 ether;

        vm.deal(buyer1, buyersNativeBalance);
        vm.deal(buyer2, buyersNativeBalance);

        uint256 offerPrice1 = listingParams.reservePricePerToken + 0.1 ether;
        uint256 offerPrice2 = offerPrice1 + 0.1 ether;

        // Warp to auction start
        vm.warp(101);

        // First bidder bids
        vm.prank(buyer1);
        color.offer{value: offerPrice1}(listingId, listingParams.quantityToList, listingParams.currency, offerPrice1, 290);

        // Check the current winning bid is by the first bidder
        IColorMarketplace.Offer memory currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer1);

        // Check that market has the offer in escrow
        assertEq(weth.balanceOf(address(color)), offerPrice1);
        
        // Second bidder bids
        vm.prank(buyer2);
        color.offer{value: offerPrice2}(listingId, listingParams.quantityToList, listingParams.currency, offerPrice2, 290);
        
        // Check the current winning bid is by the second bidder
        currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer2);

        // Check that market has the offer in escrow
        assertEq(weth.balanceOf(address(color)), offerPrice2);

        // Check that buyer1 was refunded
        assertEq(buyer1.balance, buyersNativeBalance - offerPrice2);

        // Warp to end of auction
        vm.warp(21000);

        // Check that buyer2 can close the auction
        vm.prank(buyer2);
        color.closeAuction(listingId, buyer2);

        // Check that buyer2 has the token and is less the funds
        assertEq(erc721.balanceOf(buyer2), 1);
        assertEq(buyer2.balance, buyersNativeBalance - offerPrice2);

        // Check that seller doesn't have funds before claiming themselves
        assertEq(seller.balance, 0);
        assertEq(weth.balanceOf(address(color)), offerPrice2);

        // Seller claims the funds
        vm.warp(21001); // Must warp to next block to allow seller to claim
        vm.prank(seller);
        color.closeAuction(listingId, seller);

        // Check that seller has the funds
        assertEq(seller.balance, offerPrice2 - color.calculatePlatformFee(offerPrice2));

        // Check that the market doesnt have anything in escrow
        assertEq(erc721.balanceOf(address(color)), 0);
        assertEq(weth.balanceOf(address(color)), 0);
    }

    // Bidder bids on own auction
    function test_bidOwnAuction_native_success() public {
        // List auction
        IColorMarketplace.ListingParameters memory listingParams = createBasicAuctionEther();
        uint256 listingId = 0;

        // Set up
        address buyer1 = getActor(11);
        address buyer2 = seller; // This is the only difference from "test_outbidding_native_success"

        uint256 buyersNativeBalance = 10 ether;

        vm.deal(buyer1, buyersNativeBalance);
        vm.deal(buyer2, buyersNativeBalance);

        uint256 offerPrice1 = listingParams.reservePricePerToken + 0.1 ether;
        uint256 offerPrice2 = offerPrice1 + 0.1 ether;

        // Warp to auction start
        vm.warp(101);

        // First bidder bids
        vm.prank(buyer1);
        color.offer{value: offerPrice1}(listingId, listingParams.quantityToList, listingParams.currency, offerPrice1, 290);

        // Check the current winning bid is by the first bidder
        IColorMarketplace.Offer memory currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer1);

        // Check that market has the offer in escrow
        assertEq(weth.balanceOf(address(color)), offerPrice1);
        
        // Second bidder bids
        vm.prank(buyer2);
        color.offer{value: offerPrice2}(listingId, listingParams.quantityToList, listingParams.currency, offerPrice2, 290);
        
        // Check the current winning bid is by the second bidder
        currentWinningOffer = color.getWinningBid(listingId);
        assertEq(currentWinningOffer.offeror, buyer2);

        // Check that market has the offer in escrow
        assertEq(weth.balanceOf(address(color)), offerPrice2);

        // Check that buyer1 was refunded
        assertEq(buyer1.balance, buyersNativeBalance);

        // Warp to end of auction
        vm.warp(21000);

        // Check that buyer2 can close the auction
        // note: This will also claim the funds in the same closeAuction call due to logic there
        vm.prank(buyer2);
        color.closeAuction(listingId, buyer2);

        // Check that buyer2 has the token
        // Also check that the seller who bought own token has only less the tax
        // buyer 2 == seller as defined earlier
        assertEq(erc721.balanceOf(buyer2), 1);
        assertEq(buyer2.balance, buyersNativeBalance - color.calculatePlatformFee(offerPrice2));

        // Check that the market doesnt have anything in escrow
        assertEq(erc721.balanceOf(address(color)), 0);
        assertEq(weth.balanceOf(address(color)), 0);
    }


    // Bidder wins, then attempts to double claim (closeAuction) before the lister can claim moneys
    function test_doubleClaim_erc20_failure() public {
        IColorMarketplace.ListingParameters memory listingParams = createBasicAuction();
        uint256 listingId = 0;
        uint256 offerPrice = listingParams.reservePricePerToken + 0.5 ether;

        uint256 buyerErc20Balance = 100 ether;
        give_erc20(buyer, buyerErc20Balance);

        // Warp to middle of buying time period
        vm.warp(150);

        vm.prank(buyer);
        color.offer(listingId, listingParams.quantityToList, listingParams.currency, offerPrice, 290);
        
        // Warp to after auction
        // Must take into account the time buffer (15 minutes)
        vm.warp(2201);

        // Bidder closes auction to retrieve the token
        vm.prank(buyer);
        color.closeAuction(listingId, buyer);

        vm.warp(2202);

        // Attempt to double claim
        vm.prank(buyer);

        try color.closeAuction(listingId, buyer) {
            // This block will be executed if the call does not revert
            assertTrue(false, "Expected call to revert, but it didn't");
        } catch (bytes memory lowLevelData) {
            // This block will be executed if the call reverts without a reason
            // note: Couldn't get expectEvent to work with the "ERC721InsufficientApproval" error so I hardcoded the revert memory :-)
            assertEq(lowLevelData, hex"177e802f0000000000000000000000005991a2df15a8f6a256d3ec51e99254cd3fb576a90000000000000000000000000000000000000000000000000000000000000000");
        }
    }
    
    // Here we test the case where the auction has ended and the bidder attempts to bid
    function test_bidOnEndedAuction_failure() public {vm.skip(true);}

    // Here we ensure listing with bad paramters fails
    function test_createAuction_invalidParameters_failure() public {vm.skip(true);}

}
