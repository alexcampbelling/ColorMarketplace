// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// List of todos before git repo push
// todo: approval check for listing items confirm this happens
// todo: overflow checks, use safemath everywhere
// todo: abstract types to a library
// todo: unit tests
// todo: abstract internal private functions to a library

/**
 * @title Color Marketplace (v1.0.0-alpha)
 * @dev Core Color NFT exchange contract for the Story Protocol.
 * @author alexcampbelling
 * @custom:experimental This is an experimental contract.
 */
contract ColorMarketplace is ReentrancyGuard {

    /* Types */
    enum TokenType {
        ERC721,
        ERC1155
    }

    struct Listing {
        TokenType tokenType;
        address contractAddress;
        address seller;
        uint256 listingId;
        uint256 tokenId;
        uint256 price;
        uint256 amount;
        uint256 availableAmount;
    }

    /* Constants */
    string public constant NAME = "Color Marketplace";
    string public constant VERSION = "1.0.0-alpha";

    /* Variables */
    // Here we use a incremental id since only this contract is creating listings
    // If we want mutliple contracts to make listings later, we can make this a hash
    uint256 private currentListingId = 0;

    /* Storage */
    mapping(uint256 => Listing) public listings;

    /* Events */
    // Remember: indexed means quick filtering of txn logs
    // todo: I can have three indexed in each event, should figure out what we could use for faster indexing
    event ListingCreated(
        TokenType tokenType,
        address contractAddress,
        address indexed seller,
        uint256 indexed listingId,
        uint256 tokenId,
        uint256 price,
        uint256 amount
    );
    // todo: check that no price / amount needed in this event
    event ListingRemoved(
        TokenType tokenType,
        address contractAddress,
        address indexed seller,
        uint256 indexed listingId,
        uint256 tokenId
    );
    // todo: do we want more information here, or infer that Color backend has this in database?
    event ItemBought(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price,
        uint256 amount
    );

    /* Custom errors */
    // todo: confirm these parameters are correct
    error NotTokenOwner(address caller, uint256 tokenId);
    error InvalidArrayLength();
    error InsufficientPayment(uint256 sent, uint256 required);
    error SellerDoesNotOwnToken();
    error ContractNotApproved();
    error SellerDoesNotHaveEnoughTokens();
    error InvalidTokenType();
    error CannotBuyOwnListing();
    error ListingNotAvailable(uint256 listingId);
    error NotEnoughTokensAvailable();
    error PriceMustBeGreaterThanZero();
    error AmountMustBeGreaterThanZero();
    error ListingDoesNotExist(uint256 listingId);
    error NotListingOwner(address caller, uint256 listingId);
    error CannotBuyPartialERC721(uint256 tokenId);

    /* External functions */

    /**
     * @dev Lists an NFT for sale on the marketplace.
     * Transfers the NFT from the seller to the marketplace contract.
     * Emits an {ItemListed} event.
     *
     * Requirements:
     * - `msg.sender` must be the owner of the NFT.
     *
     * @param tokenType The type of the token (ERC721 or ERC1155).
     * @param contractAddress The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @param price The price to list the NFT for.
     * @param amount The amount of the NFT to list.
     */
    function createListing(
        TokenType tokenType,
        address contractAddress,
        uint256 tokenId,
        uint256 price,
        uint256 amount
    ) public nonReentrant returns (uint256 listingId) {
        // Initial checks
        if (price <= 0) revert PriceMustBeGreaterThanZero();
        if (amount <= 0) revert AmountMustBeGreaterThanZero();

        // Create listing object
        listingId = currentListingId++;
        Listing storage newListing = listings[listingId];

        newListing.tokenType = tokenType;
        newListing.contractAddress = contractAddress;
        newListing.seller = msg.sender;
        newListing.listingId = listingId;
        newListing.tokenId = tokenId;
        newListing.price = price;
        newListing.amount = amount;
        newListing.availableAmount = amount;

        // Check listing requirements
        checkTokenRequirements(newListing, amount);
        transferToken(newListing, address(this), amount);

        currentListingId++;
        listings[currentListingId] = newListing;

        emit ListingCreated(
            tokenType,
            contractAddress,
            msg.sender,
            currentListingId,
            tokenId,
            price,
            amount
        );

        return currentListingId;
    }

    /**
     * @dev Lists multiple items for sale on the marketplace.
     *
     * Requirements:
     * - Lengths of each parameter array must be equal.
     *
     * @param tokenTypes An array of token types for the items.
     * @param contractAddresses An array of contract addresses for the items.
     * @param tokenIds An array of token IDs for the items.
     * @param prices An array of prices for the items.
     * @param amounts An array of amounts for the items.
     */
    function listBatchItems(
        TokenType[] memory tokenTypes,
        address[] memory contractAddresses,
        uint256[] memory tokenIds,
        uint256[] memory prices,
        uint256[] memory amounts
    ) public {
        if (
            tokenTypes.length != contractAddresses.length ||
            contractAddresses.length != tokenIds.length ||
            tokenIds.length != prices.length ||
            prices.length != amounts.length
        ) {
            revert InvalidArrayLength();
        }

        for (uint256 i = 0; i < tokenTypes.length; i++) {
            createListing(
                tokenTypes[i],
                contractAddresses[i],
                tokenIds[i],
                prices[i],
                amounts[i]
            );
        }
    }

    /**
     * @dev Removes a listing from the marketplace.
     * The listing's token will be transferred back to the owner.
     * Emits a {ListingRemoved} event.
     *
     * Requirements:
     * - The listing must exist.
     * - Only the owner of the listing can remove it.
     *
     * @param listingId The ID of the listing to be removed.
     */
    function removeListItem(uint256 listingId) public {
        Listing storage listing = listings[listingId];
        if (listing.seller == address(0)) {
            revert ListingDoesNotExist(listingId);
        }
        if (listing.seller != msg.sender) {
            revert NotListingOwner(msg.sender, listingId);
        }

        // Remove the entire amount of the listing
        transferToken(listing, msg.sender, listing.amount);

        delete listings[listingId];

        emit ListingRemoved(
            listing.tokenType,
            listing.contractAddress,
            msg.sender,
            listingId,
            listing.tokenId
        );
    }

    /**
     * @dev Allows a user to buy an item from the marketplace.
     * Emits a {ItemBought} event.
     *
     * Requirements:
     * - The value sent must be greater than or equal to the price of the listing.
     *
     * @param listingId The ID of the listing to be bought.
     */
    function buyListing(
        uint256 listingId,
        uint256 amount
    ) public payable nonReentrant {
        Listing storage listing = listings[listingId];

        // Perform checks on the listing
        performBuyListingChecks(listing, msg.sender);

        // Check token requirements
        checkTokenRequirements(listing, amount);

        // Transfer payment to seller
        uint256 totalPrice = listing.price * amount;
        if (msg.value < totalPrice) {
            revert InsufficientPayment(msg.value, listing.price);
        }
        payable(listing.seller).transfer(totalPrice);

        // Transfer token to buyer
        transferToken(listing, msg.sender, amount);

        // Update listing amount
        if (listing.tokenType == TokenType.ERC1155) {
            listing.availableAmount -= amount;
        } else {
            listing.availableAmount = 0;
        }

        if (listing.availableAmount == 0) {
            delete listings[listingId];
        }

        // todo: decide how we will emit partial buys of 1155, emitting a different message maybe
        emit ItemBought(listingId, msg.sender, listing.price, amount);
    }

    /* Internal functions */

    /**
     * @dev Checks the requirements for a given listing before executing a transaction, given its token type.
     *
     * Requirements:
     * - For ERC721 tokens:
     *   - The seller must be the owner of the token.
     *   - The marketplace contract must be approved to transfer the token.
     * - For ERC1155 tokens:
     *   - The seller must have enough tokens to fulfill the transaction.
     *   - The marketplace contract must be approved to transfer the tokens.
     * - The token type must be valid.
     *
     * @param listing The listing to check requirements for.
     * @param amount The amount of tokens being transacted.
     */
    function checkTokenRequirements(
        Listing storage listing,
        uint256 amount
    ) internal view {
        if (listing.tokenType == TokenType.ERC721) {
            IERC721 token721 = IERC721(listing.contractAddress);
            if (token721.ownerOf(listing.tokenId) != listing.seller) {
                revert SellerDoesNotOwnToken();
            }
            if (!token721.isApprovedForAll(msg.sender, address(this))) {
                revert ContractNotApproved();
            }
            if (amount != 1) {
                revert CannotBuyPartialERC721(listing.tokenId);
            }
        } else if (listing.tokenType == TokenType.ERC1155) {
            IERC1155 token1155 = IERC1155(listing.contractAddress);
            if (token1155.balanceOf(listing.seller, listing.tokenId) < amount) {
                revert SellerDoesNotHaveEnoughTokens();
            }
            if (!token1155.isApprovedForAll(msg.sender, address(this))) {
                revert ContractNotApproved();
            }
        } else {
            revert InvalidTokenType();
        }
    }

    /**
     * @dev Transfers tokens from the marketplace contract to the buyer.
     * @param listing The listing.
     * @param buyer The buyer address for the listing.
     */
    function transferToken(
        Listing storage listing,
        address buyer,
        uint256 amount
    ) private {
        if (listing.tokenType == TokenType.ERC721) {
            IERC721 token = IERC721(listing.contractAddress);
            token.transferFrom(address(this), buyer, listing.tokenId);
        } else if (listing.tokenType == TokenType.ERC1155) {
            IERC1155 token = IERC1155(listing.contractAddress);
            token.safeTransferFrom(
                address(this),
                buyer,
                listing.tokenId,
                amount,
                ""
            );
        }
    }

    /**
     * @dev Performs various checks before allowing a listing to be purchased.
     *
     * Requirements:
     * - The listing must exist.
     * - The buyer must not be the seller.
     * - The listing must be available.
     * @param listing The listing to be checked.
     * @param buyer The address of the buyer.
     */
    function performBuyListingChecks(
        Listing storage listing,
        address buyer
    ) private view {
        if (listing.seller == address(0)) {
            revert ListingDoesNotExist(listing.listingId);
        }

        if (listing.seller == buyer) {
            revert CannotBuyOwnListing();
        }

        if (listing.amount == 0) {
            revert ListingNotAvailable(listing.listingId);
        }
    }
}
