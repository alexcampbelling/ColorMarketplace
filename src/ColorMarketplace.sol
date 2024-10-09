// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

/**
 * @title Color Marketplace (v2.0)
 * @author alexcampbelling
 */

/* External imports */

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* Internal imports */

import "./IColorMarketplace.sol";
import "./CurrencyTransferLib.sol";

/* Story specific */

import { ILicenseToken } from "./ILicenseToken.sol";

/// @title ColorMarketplace AKA Color
contract ColorMarketplace is
    IColorMarketplace,
    ReentrancyGuard,
    ERC2771Context,
    AccessControl,
    IERC721Receiver
{
    // Contract information
    string public constant NAME = "Color Marketplace"; // The name of the marketplace
    string public constant VERSION = "2.0.0"; // The version of the marketplace contract
    string public contractURI; // The URI for the contract level metadata

    // Token contracts
    address private immutable NATIVE_TOKEN_WRAPPER; // The address of the native token wrapper contract (equivalent to WETH)
    ILicenseToken public licenseToken; // The address of the license token contract, used to check for transferability
    mapping(address => bool) public erc20Whitelist; // A whitelist of ERC20 tokens that can be used in the marketplace

    // Marketplace settings
    uint64 public constant MAX_BPS = 10_000; // The maximum basis points (bps) value, equivalent to 100%
    uint64 private platformFeeBps; // The percentage of primary sales collected as platform fees, in bps
    // uint64 public timeBuffer; // The amount of time added to an auction's 'endTime' if a bid is made within `timeBuffer` seconds of the existing `endTime`
    // uint64 public bidBufferBps; // The minimum percentage increase required from the previous winning bid, in bps

    // Marketplace state
    uint256 public totalListings; // The total number of listings ever created in the marketplace
    address private platformFeeRecipient; // The address that receives the platform fees
    mapping(uint256 => Listing) public listings; // A mapping from listing UID to listing info
    mapping(uint256 => mapping(address => Offer)) public offers; // A mapping from listing UID to a nested mapping from offeror address to the offer they made
    mapping(uint256 => Offer) public winningBid; // A mapping from auction listing UID to the current winning bid

    /* Modifiers */

    /**
     * @dev Ensures the token is either the native token or a whitelisted ERC20 token.
     *
     * Requirements:
     * - `tokenAddress` must be either the native token or a token in the `erc20Whitelist`.
     *
     * @param tokenAddress The address of the token.
     */
    modifier onlyWhitelistedErc20s(address tokenAddress) {
        if (tokenAddress != CurrencyTransferLib.NATIVE_TOKEN && !erc20Whitelist[tokenAddress]) {
            revert TokenNotAccepted();
        }
        _;
    }

    /**
     * @dev Ensures the caller is the creator of the listing.
     *
     * Requirements:
     * - `msg.sender` must be the owner of the listing.
     *
     * @param _listingId The ID of the listing.
     */
    modifier onlyListingCreator(uint256 _listingId) {
        if (listings[_listingId].tokenOwner != _msgSender()) {
            revert NotListingOwner();
        }
        _;
    }

    /**
     * @dev Checks whether a listing exists.
     *
     * Requirements:
     * - The `assetContract` field of the listing must not be the zero address.
     *
     * @param _listingId The ID of the listing.
     */
    modifier onlyExistingListing(uint256 _listingId) {
        if (listings[_listingId].assetContract == address(0)) {
            revert ListingDoesNotExist();
        }
        _;
    }

    /* Constructor and initialiser */

    constructor(
        address _nativeTokenWrapper,
        address _trustedForwarder,
        address _defaultAdmin,
        string memory _contractURI,
        address _platformFeeRecipient,
        uint256 _platformFeeBps,
        address[] memory _erc20Whitelist,
        address _licenseTokenAddress
    ) ERC2771Context(_trustedForwarder)  {
        NATIVE_TOKEN_WRAPPER = _nativeTokenWrapper;

        // timeBuffer = 15 minutes;
        // bidBufferBps = 500;

        contractURI = _contractURI;
        platformFeeBps = uint64(_platformFeeBps);
        platformFeeRecipient = _platformFeeRecipient;
        
        for (uint i = 0; i < _erc20Whitelist.length; i++) {
            erc20Whitelist[_erc20Whitelist[i]] = true;
        }

        licenseToken = ILicenseToken(_licenseTokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    /**
     * @dev Allows the contract to receive native tokens from `nativeTokenWrapper` withdraw.
     *
     * Emits a {ReceivedEther} event.
     *
     * Requirements:
     * - The function must be called by a payable transaction.
     */
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }

    /**
     * @dev Handles the receipt of an ERC721 token.
     *
     * This function is called by an ERC721 contract when a token is transferred to this contract.
     * It returns a bytes4 value to signal that the transfer was accepted.
     *
     * @return bytes4 `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @dev Creates a new listing on the marketplace.
     *
     * Emits a {ListingAdded} event.
     *
     * Requirements:
     * - `msg.sender` must be the owner of the NFT.
     * - The currency of the listing must be whitelisted.
     * - The quantity of tokens to list must be greater than 0.
     * - The listing must not start in the past.
     * - The token must be valid and approved for transfer.
     * - If the listing is an auction, the buyout price must not be less than the reserve price.
     *
     * @param _params The parameters for the listing. See IColorMarketplace.sol for more details.
     */
    function createListing(ListingParameters memory _params) external override {
        _createListingInternal(_params);
    }

    /**
     * @dev Creates multiple new listings on the marketplace.
     *
     * Emits a {ListingAdded} event for each new listing.
     *
     * Requirements:
     * - `msg.sender` must be the owner of the NFTs.
     * - The currency of each listing must be whitelisted.
     * - The quantity of tokens to list in each listing must be greater than 0.
     * - Each listing must not start in the past.
     * - The tokens in each listing must be valid and approved for transfer.
     * - If a listing is an auction, the buyout price must not be less than the reserve price.
     *
     * @param _paramsArray An array of parameters for the listings.
     */
    function createListingsBatch(ListingParameters[] memory _paramsArray) external {
        for (uint256 i = 0; i < _paramsArray.length; i++) {
            _createListingInternal(_paramsArray[i]);
        }
    }

    /**
     * @dev Creates a new listing on the marketplace.
     *
     * This is an internal function that is called by `createListing` and `createListingsBatch`.
     * It collates all the necessary data for the listing, validates the ownership and approval of the tokens,
     * and creates a new `Listing` struct. If the listing type is an auction, it transfers the tokens to be listed
     * to the marketplace contract.
     *
     * Emits a {ListingAdded} event.
     *
     * Requirements:
     * - `msg.sender` must be the owner of the NFT.
     * - The currency of the listing must be whitelisted.
     * - The listing must not start in the past.
     * - The token must be valid and approved for transfer.
     * - If the listing is an auction, the buyout price must not be less than the reserve price.
     *
     * @param _params The parameters for the listing.
     */
    function _createListingInternal(ListingParameters memory _params) internal onlyWhitelistedErc20s(_params.currency) {
        // Collate all lisiting data
        uint256 listingId = totalListings;
        totalListings += 1;
        address tokenOwner = _msgSender();

        uint256 startTime = _params.startTime;

        if (startTime < block.timestamp) {
            // do not allow listing to start in the past (1 hour buffer)
            if (block.timestamp - startTime >= 1 hours) {
                revert InvalidStartTime();
            }
            startTime = block.timestamp;
        }

        if (!validateOwnershipAndApproval(
            tokenOwner,
            _params.assetContract,
            _params.tokenId
        )) {
            revert TokenNotValidOrApproved();
        }

        Listing memory newListing = Listing({
            listingId: listingId,
            tokenOwner: tokenOwner,
            assetContract: _params.assetContract,
            tokenId: _params.tokenId,
            startTime: startTime,
            endTime: startTime + _params.secondsUntilEndTime,
            currency: _params.currency,
            reservePrice: _params.reservePrice,
            buyoutPrice: _params.buyoutPrice,
            listingType: _params.listingType,
            status: ListingStatus.Open
        });

        listings[listingId] = newListing;

        // Tokens listed for sale in an auction are escrowed in Marketplace.
        // if (newListing.listingType == ListingType.Auction) {
        //     if (
        //         newListing.buyoutPrice != 0 &&
        //         newListing.buyoutPrice < newListing.reservePrice
        //     ) {
        //         revert InvalidPrice();
        //     }
        //     // todo: transferListingTokens -> pure transfer (check this later)
        //     IERC721(newListing.assetContract).safeTransferFrom(
        //         tokenOwner,
        //         address(this),
        //         newListing.tokenId
        //     );
        // }

        emit ListingAdded(
            listingId,
            _params.assetContract,
            tokenOwner,
            newListing
        );
    }

    /**
     * @dev Updates an existing listing on the marketplace.
     *
     * Emits a {ListingUpdated} event.
     *
     * Requirements:
     * - `msg.sender` must be the creator of the listing.
     * - The currency of the listing must be whitelisted.
     * - The listing must not start in the past.
     * - The token must be valid and approved for transfer.
     * - If the listing is an auction, it must not have already started.
     * - If the listing is an auction, the buyout price must not be less than the reserve price.
     *
     * @param _listingId The ID of the listing to update.
     * @param _currency The new currency for the listing.
     * @param _reservePrice The new reserve price for token.
     * @param _buyoutPrice The new buyout price for token.
     * @param _startTime The new start time for the listing.
     * @param _secondsUntilEndTime The new number of seconds until the end time.
     */
    // todo alex: remove auction checks here, check updte direct listing logic tests still pass
    function updateListing(
        uint256 _listingId,
        address _currency,
        uint256 _reservePrice,
        uint256 _buyoutPrice,
        uint256 _startTime,
        uint256 _secondsUntilEndTime
    ) onlyWhitelistedErc20s(_currency) external override onlyListingCreator(_listingId) {
        Listing memory targetListing = listings[_listingId];
        // bool isAuction = targetListing.listingType == ListingType.Auction;

        // Todo alex: test for this
        if (targetListing.status != ListingStatus.Open) {
            revert ListingNotOpen();
        }

        // Can only edit auction listing before it starts.
        // if (isAuction) {
        //     if (block.timestamp >= targetListing.startTime) {
        //         revert ListingAlreadyStarted();
        //     }

        //     if (
        //         _buyoutPrice != 0 &&
        //         _buyoutPrice < _reservePrice
        //     ) {
        //         revert InvalidPrice();
        //     }
        // }

        if (_startTime < block.timestamp) {
            // do not allow listing to start in the past (1 hour buffer)
            if (block.timestamp - _startTime >= 1 hours) {
                revert InvalidStartTime();
            }
            _startTime = block.timestamp;
        }

        uint256 newStartTime = _startTime == 0
            ? targetListing.startTime
            : _startTime;

        listings[_listingId] = Listing({
            listingId: _listingId,
            tokenOwner: _msgSender(),
            assetContract: targetListing.assetContract,
            tokenId: targetListing.tokenId,
            startTime: newStartTime,
            endTime: _secondsUntilEndTime == 0
                ? targetListing.endTime
                : newStartTime + _secondsUntilEndTime,
            currency: _currency,
            reservePrice: _reservePrice,
            buyoutPrice: _buyoutPrice,
            listingType: targetListing.listingType, // todo alex: remove this when ready
            status: ListingStatus.Open
        });

        // Validate ownership and approval for the token
        if (!validateOwnershipAndApproval(
            targetListing.tokenOwner,
            targetListing.assetContract,
            targetListing.tokenId
        )) {
            revert TokenNotValidOrApproved();
        }

        // todo alex: remove auction logic
        // if (isAuction && IERC721(targetListing.assetContract).ownerOf(targetListing.tokenId) == address(this)) {
        //     revert NotInEscrow();
        // }

        emit ListingUpdated(_listingId, targetListing.tokenOwner);
    }

    /**
     * @dev Cancels a direct listing on the marketplace.
     *
     * This function allows the creator of a direct listing to cancel it. It first checks if the listing is a direct listing,
     * and if it is, it deletes the listing and emits a {ListingRemoved} event.
     *
     * Requirements:
     * - `msg.sender` must be the creator of the listing.
     * - The listing must be a direct listing.
     *
     * @param _listingId The ID of the listing to cancel.
     */
    function cancelDirectListing(
        uint256 _listingId
    ) public onlyListingCreator(_listingId) {
        Listing memory targetListing = listings[_listingId];

        // todo alex: remove when removing audits
        // if (targetListing.listingType != ListingType.Direct) {
        //     revert NotDirectListing();
        // }

        if (targetListing.status != ListingStatus.Open) {
            revert ListingNotOpen();
        }

        listings[_listingId].status = ListingStatus.Cancelled;

        emit ListingCancelled(_listingId, targetListing.tokenOwner);
    }

    /**
     * @dev Cancels multiple direct listings on the marketplace.
     *
     * This function allows the caller to cancel multiple direct listings at once. It takes an array of listing IDs as input,
     * and for each ID in the array, it calls the `cancelDirectListing` function.
     *
     * @param _listingIds An array of the IDs of the listings to cancel.
     */
    function cancelDirectListings(
        uint256[] memory _listingIds
    ) external {
        for (uint256 i = 0; i < _listingIds.length; i++) {
            cancelDirectListing(_listingIds[i]);
        }
    }

    // todo alex: since removing erc1155, check names for total price here make sense
    function validateCommonSale(
        Listing memory _listing,
        address _payer,
        address _currency,
        uint256 settledTotalPrice
    ) internal {
        // Check: buyer owns and has approved sufficient currency for sale.
        if (_currency == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != settledTotalPrice) {
                revert InvalidMsgValue();
            }
        } else {
            validateERC20BalAndAllowance(_payer, _currency, settledTotalPrice);
        }

        // Check whether token owner owns and has approved `quantityToBuy` amount of listing tokens from the listing.
        if (!validateOwnershipAndApproval(
            _listing.tokenOwner,
            _listing.assetContract,
            _listing.tokenId
        )) {
            revert TokenNotValidOrApproved();
        }
    }

    function validateDirectListingSale(
        Listing memory _listing,
        address _payer,
        address _currency,
        uint256 settledTotalPrice
    ) internal {
        // todo alex: Remove this once we only offer direct sales
        // if (_listing.listingType != ListingType.Direct) {
        //     revert NotDirectListing();
        // }

        // Check if sale is made within the listing window.
        // todo alex: check for listing status is open here too, check elsewhere this style check is being done too
        if (
            block.timestamp >= _listing.endTime ||
            block.timestamp <= _listing.startTime
        ) {
            // revert NotWithinSaleWindow();
            revert InactiveListing(
                _listing.startTime,
                _listing.endTime,
                block.timestamp
            );
        }

        // Perform common validations
        validateCommonSale(_listing, _payer, _currency, settledTotalPrice);
    }

    // todo: enable this code via removing checks in handling offers
    // function validateAuctionSale(
    //     Listing memory _listing,
    //     address _payer,
    //     uint256 _quantityToBuy,
    //     address _currency,
    //     uint256 settledTotalPrice
    // ) internal {
    //     if (_listing.listingType != ListingType.Auction) {
    //         revert NotAuctionListing();
    //     }

    //     // Check if the auction is still active.
    //     if (block.timestamp >= _listing.endTime) {
    //         revert AuctionEnded();
    //     }

    //     // Check if the bid is higher than the current highest bid.
    //     Offer memory currentHighestBid = winningBid[_listing.listingId];
    //     if (settledTotalPrice <= currentHighestBid.price * _quantityToBuy) {
    //         revert BidTooLow();
    //     }

    //     // Perform common validations
    //     validateCommonSale(_listing, _payer, _quantityToBuy, _currency, settledTotalPrice);
    // }

    function validateERC20BalAndAllowance(
        address _addrToCheck,
        address _currency,
        uint256 _currencyAmountToCheckAgainst
    ) internal view {
        uint256 balance = IERC20(_currency).balanceOf(_addrToCheck);
        uint256 allowance = IERC20(_currency).allowance(_addrToCheck, address(this));
        bool isBalanceInsufficient = balance < _currencyAmountToCheckAgainst;
        bool isAllowanceInsufficient = allowance < _currencyAmountToCheckAgainst;
        if (isBalanceInsufficient || isAllowanceInsufficient) {
            revert InsufficientBalanceOrAllowance();
        }
    }

    struct CurrencyTotal {
        address currency;
        uint256 totalPrice;
    }

    function validateBulkBuy(
        uint256[] memory _listingIds,
        address _payer,
        address[] memory _currencies,
        uint256[] memory _totalPrices
    ) internal view {
        uint256 totalNativeValue = 0;

        CurrencyTotal[] memory currencyTotals = new CurrencyTotal[](_listingIds.length);
        uint256 uniqueCurrencyCount = 0;

        // Iterate over each listing
        for (uint256 i = 0; i < _listingIds.length; i++) {
            // Ensure the listing exists
            if (listings[_listingIds[i]].assetContract == address(0)) {
                revert ListingDoesNotExist();
            }

            // Retrieve the listing from storage
            // Listing memory listing = listings[_listingIds[i]];

            // Check if the listing is an auction and if the offer meets the buyout price
            // if (listing.listingType == ListingType.Auction) {
            //     if (_totalPrices[i] < listing.buyoutPrice) {
            //         revert OfferDoesNotMeetBuyoutPrice();
            //     }
            // }
            
            // Accumulate total prices per currency
            bool found = false;
            for (uint256 j = 0; j < currencyTotals.length; j++) {
                if (currencyTotals[j].currency == _currencies[i]) {
                    currencyTotals[j].totalPrice += _totalPrices[i];
                    found = true;
                    break;
                }
            }
            if (!found) {
                currencyTotals[i] = CurrencyTotal(_currencies[i], _totalPrices[i]);
                uniqueCurrencyCount++;
            }
            
            if (_currencies[i] == CurrencyTransferLib.NATIVE_TOKEN) {
                // This has ability to panic overflow
                // Solidity 0.8 makes this panic with "panic: arithmetic underflow or overflow (0x11)"
                totalNativeValue += _totalPrices[i];
            }
        }

        // Validate total native token value
        if (msg.value != totalNativeValue) {
            revert InvalidMsgValue();
        }

        // todo alex: confirm this works as intended
        // why are we iterating over a unique currency count, shouldnt we do this for each currency?
        // or are we totalling the total required of each currency and then checking against that?
        // REGARDLESS, we need comments explaining this part more.

        // Validate total ERC20 token values
        for (uint256 i = 0; i < uniqueCurrencyCount; i++) {
            if (currencyTotals[i].currency != CurrencyTransferLib.NATIVE_TOKEN) {
                
                validateERC20BalAndAllowance(_payer, currencyTotals[i].currency, currencyTotals[i].totalPrice);
            }
        }
    }

    function executeDirectSale(
        Listing memory _targetListing,
        address _payer,
        address _receiver,
        address _currency,
        uint256 _currencyAmountToTransfer
    ) internal {
        // Notes: 
        // - Must validate before calling this function
        // - This only works for direct listings

        // Todo Alex: Check this via a test
        // todo alex: try list, send the token somewhere else, then try buy. should fail
        listings[_targetListing.listingId].status = ListingStatus.Closed;

        // 2. Payout transaction with fees
        payout(
            _payer,
            _targetListing.tokenOwner,
            _currency,
            _currencyAmountToTransfer,
            _targetListing
        );

        // 3. Transfer tokens
        // todo: transferListingTokens -> pure transfer (check this later)
        IERC721(_targetListing.assetContract).safeTransferFrom(
            _targetListing.tokenOwner,
            _receiver,
            _targetListing.tokenId
        );

        emit NewSale(
            _targetListing.listingId,
            _targetListing.assetContract,
            _targetListing.tokenOwner,
            _receiver,
            _currencyAmountToTransfer
        );
    }

    /**
     * @dev Buys a listing on the marketplace.
     *
     * This function is a public wrapper for the `_buy` function. It is necessary to prevent reentry attacks,
     * but it can still be called with bulk buys.
     *
     * @param _listingId The ID of the listing to buy.
     * @param _buyFor The address to buy the listing for.
     * @param _currency The currency to use for the purchase.
     * @param _totalPrice The total price of the purchase.
     */    
    function buy(
        uint256 _listingId,
        address _buyFor,
        address _currency,
        uint256 _totalPrice
    ) external payable nonReentrant onlyExistingListing(_listingId) {
        _buy(_listingId, _buyFor, _currency,_totalPrice);
    }

    /**
     * @dev Buys a listing on the marketplace.
     *
     * This function is the internal implementation of the `buy` function. It checks whether the settled total price
     * and currency to use are correct, and if they are, it executes the sale.
     *
     * @param _listingId The ID of the listing to buy.
     * @param _buyFor The address to buy the listing for.
     * @param _currency The currency to use for the purchase.
     * @param _totalPrice The total price of the purchase.
     */
    function _buy(
        uint256 _listingId,
        address _buyFor,
        address _currency,
        uint256 _totalPrice
    ) internal {
        Listing memory targetListing = listings[_listingId];
        address payer = _msgSender();

        // todo alex: add listing status check here or in validateDirectListingSale

        // Check whether the settled total price and currency to use are correct.
        if (
            _currency != targetListing.currency ||
            _totalPrice != (targetListing.buyoutPrice)
        ) {
            revert InvalidTotalPrice();
        }

        // Validate sale here now before executing transaction
        validateDirectListingSale(
            targetListing,
            payer,
            _currency,
            targetListing.buyoutPrice
        );

        executeDirectSale(
            targetListing,
            payer,
            _buyFor,
            targetListing.currency,
            targetListing.buyoutPrice
        );
    }

    // todo alex: check if this works with auctions being removed
    function bulkBuy(
        uint256[] memory _listingIds,
        address[] memory _buyers,
        address[] memory _currencies,
        uint256[] memory _totalPrices
    ) external payable nonReentrant {
        address payer = _msgSender();
        validateBulkBuy(_listingIds, payer, _currencies, _totalPrices);
        uint256 remainingValue = msg.value;

        for (uint256 i = 0; i < _listingIds.length; i++) {

            Listing memory listing = listings[_listingIds[i]];

            // Close out auction for the buyer
            // if (listing.listingType == ListingType.Auction) {
            //     Offer memory newOffer = Offer({
            //         listingId: _listingIds[i],
            //         offeror: payer,
            //         currency: _currencies[i],
            //         price: _totalPrices[i],
            //         expirationTimestamp: block.timestamp // Assuming immediate execution
            //     });
            //     handleBid(listing, newOffer, false, remainingValue);
            // } else {
                executeDirectSale(
                    listing,
                    payer,
                    _buyers[i],
                    _currencies[i],
                    _totalPrices[i]
                );
                
            // }

            // Reduce a running count of remaining native value to ensure no overpayment for bulk buying auctions
            if (_currencies[i] == CurrencyTransferLib.NATIVE_TOKEN) {
                remainingValue -= _totalPrices[i];
            }
        }
    }


    /**
     * @dev Accepts an offer for a direct listing on the marketplace.
     *
     * This function allows the creator of a direct listing to accept an offer for it. It first checks if the offer's currency
     * and price per token are correct, and if the offer has not expired. If all checks pass, it deletes the offer and executes
     * the sale.
     *
     * Note: This function is for direct listings only. Auctions must wait to close auction.
     *
     * @param _listingId The ID of the listing to accept the offer for.
     * @param _offeror The address of the offeror.
     * @param _currency The currency of the offer.
     * @param _price The price for token of the offer.
     */    
    // todo alex: need to fully test this as the idea of making an offer on direct listing still sounds good!
    function acceptOffer(
        uint256 _listingId,
        address _offeror,
        address _currency,
        uint256 _price
    )
        external
        override
        nonReentrant
        onlyListingCreator(_listingId)
        onlyExistingListing(_listingId)
    {
        Offer memory targetOffer = offers[_listingId][_offeror];
        Listing memory targetListing = listings[_listingId];

        if (
            _currency != targetOffer.currency ||
            _price != targetOffer.price
        ) {
            revert InvalidPrice();
        }

        if (targetOffer.expirationTimestamp <= block.timestamp) {
            // todo alex: can re-use another custom error here I think
            revert OfferExpired();
        }

        delete offers[_listingId][_offeror];

        validateDirectListingSale(
            targetListing,
            _offeror,
            targetOffer.currency,
            targetOffer.price
        );

        executeDirectSale(
            targetListing,
            _offeror,
            _offeror,
            targetOffer.currency,
            targetOffer.price
        );
    }

    /**
     * @dev Allows an account to make an offer to a direct listing or make a bid in an auction.
     *
     * This function first checks if the listing is active. If it is, it creates a new offer or bid. If the listing is an auction,
     * it checks if the bid is made in the auction's desired currency and if the price per token is not zero. If the listing is a direct
     * listing, it checks if the offer is not made directly in native tokens. If all checks pass, it handles the offer or bid.
     *
     * @param _listingId The ID of the listing to make the offer or bid to.
     * @param _currency The currency of the offer or bid.
     * @param _price The price for token of the offer or bid.
     * @param _expirationTimestamp The expiration timestamp of the offer or bid.
     */    
    // todo alex: check if this works with auctions being removed
    function offer(
        uint256 _listingId,
        address _currency,
        uint256 _price,
        uint256 _expirationTimestamp
    ) external payable override nonReentrant onlyExistingListing(_listingId) {
        Listing memory targetListing = listings[_listingId];

        // todo alex: comment this better, or abstract this, I think this is re-used code elsewhere
        if (
            // targetListing.status == ListingStatus.Closed || // todo alex: chance to update status?
            targetListing.endTime <= block.timestamp ||
            targetListing.startTime >= block.timestamp
        ) {
            revert InactiveListing(
                targetListing.startTime,
                targetListing.endTime,
                block.timestamp
            );
        }

        // Both - (1) offers to direct listings, and (2) bids to auctions - share the same structure.
        Offer memory newOffer = Offer({
            listingId: _listingId,
            offeror: _msgSender(),
            currency: _currency,
            price: _price,
            expirationTimestamp: _expirationTimestamp
        });

        // if (targetListing.listingType == ListingType.Auction) {
        //     // A bid to an auction must be made in the auction's desired currency.
        //     if (newOffer.currency != targetListing.currency) {
        //         revert InvalidCurrency();
        //     }

        //     if (newOffer.price == 0) {
        //         revert ZeroAmountBid();
        //     }

        //     handleBid(targetListing, newOffer, true, 0);

        // } else if (targetListing.listingType == ListingType.Direct) {
            // Prevent potentially lost/locked native token.
            if (msg.value != 0) {
                revert ValueNotNeeded();
            }

            // Offers to direct listings cannot be made directly in native tokens.
            newOffer.currency = _currency == CurrencyTransferLib.NATIVE_TOKEN
                ? NATIVE_TOKEN_WRAPPER
                : _currency;

            handleOffer(targetListing, newOffer);
        // }
    }

    /**
     * @dev Handles an offer made to a direct listing.
     * Validates the offer and updates the offers mapping.
     *
     * Emits a {NewOffer} event.
     *
     * Requirements:
     * - The quantity wanted in the offer must not exceed the quantity available in the listing.
     * - The listing must have a quantity greater than 0.
     * - The offeror must have sufficient ERC20 balance and allowance.
     *
     * @param _targetListing The listing to which the offer is made.
     * @param _newOffer The offer being made.
     */
    // todo alex: check the quanitiy logic here since removing 1155
    function handleOffer(
        Listing memory _targetListing,
        Offer memory _newOffer
    ) internal {
        validateERC20BalAndAllowance(
            _newOffer.offeror,
            _newOffer.currency,
            _newOffer.price
        );

        offers[_targetListing.listingId][_newOffer.offeror] = _newOffer;

        emit NewOffer(
            _targetListing.listingId,
            _newOffer.offeror,
            _targetListing.listingType,
            _newOffer.price,
            _newOffer.currency
        );
    }

    /**
     * @dev Handles a bid made to an auction.
     * Validates the bid and updates the winning bid if necessary.
     *
     * Emits a {NewOffer} event.
     *
     * Requirements:
     * - If there's a buyout price, the incoming offer amount must be equal to or greater than the buyout price.
     * - If there's an existing winning bid, the incoming bid amount must be bid buffer % greater.
     * - Else, the bid amount must be at least as great as the reserve price.
     *
     * @param _targetListing The listing to which the bid is made.
     * @param _incomingBid The bid being made.
     */
    // function handleBid(
    //     Listing memory _targetListing,
    //     Offer memory _incomingBid,
    //     bool useMsgValue,
    //     uint256 _customValue
    // ) internal {
    //     Offer memory currentWinningBid = winningBid[_targetListing.listingId];
    //     uint256 currentOfferAmount = currentWinningBid.price;
    //     uint256 incomingOfferAmount = _incomingBid.price;
    //     address _nativeTokenWrapper = NATIVE_TOKEN_WRAPPER;

    //     // Close auction and execute sale if there's a buyout price and incoming offer amount is buyout price.
    //     if (
    //         _targetListing.buyoutPrice > 0 &&
    //         incomingOfferAmount >=
    //         _targetListing.buyoutPrice
    //     ) {
    //         _closeAuctionForBidder(_targetListing, _incomingBid);
    //     } else {
    //         // If there's an existing winning bid, incoming bid amount must be bid buffer % greater.
    //         // Else, bid amount must be at least as great as reserve price
    //         if (
    //             !isNewWinningBid(
    //                 _targetListing.reservePrice,
    //                 currentOfferAmount,
    //                 incomingOfferAmount
    //             )
    //         ) {
    //             revert NotWinningBid();
    //         }

    //         // Update the winning bid and listing's end time before external contract calls.
    //         winningBid[_targetListing.listingId] = _incomingBid;

    //         if (_targetListing.endTime - block.timestamp <= timeBuffer) {
    //             _targetListing.endTime += timeBuffer;
    //             listings[_targetListing.listingId] = _targetListing;
    //         }
    //     }

    //     // Payout previous highest bid.
    //     if (currentWinningBid.offeror != address(0) && currentOfferAmount > 0) {
    //         CurrencyTransferLib.transferCurrencyWithWrapper(
    //             _targetListing.currency,
    //             address(this),
    //             currentWinningBid.offeror,
    //             currentOfferAmount,
    //             _nativeTokenWrapper,
    //             true,
    //             0
    //         );
    //     }

    //     // Collect incoming bid
    //     CurrencyTransferLib.transferCurrencyWithWrapper(
    //         _targetListing.currency,
    //         _incomingBid.offeror,
    //         address(this),
    //         incomingOfferAmount,
    //         _nativeTokenWrapper,
    //         useMsgValue,
    //         _customValue
    //     );

    //     emit NewOffer(
    //         _targetListing.listingId,
    //         _incomingBid.offeror,
    //         _targetListing.listingType,
    //         _incomingBid.price,
    //         _incomingBid.currency
    //     );
    // }

    /**
     * @dev Determines if an incoming bid is a new winning bid.
     * If there is no current winning bid, the incoming bid is a new winning bid if it is greater than or equal to the reserve amount.
     * If there is a current winning bid, the incoming bid is a new winning bid if it is greater than the current winning bid and the difference between the incoming bid and the current winning bid is greater than or equal to the bid buffer.
     *
     * @param _reserveAmount The reserve amount of the auction.
     * @param _currentWinningBidAmount The amount of the current winning bid.
     * @param _incomingBidAmount The amount of the incoming bid.
     * @return isValidNewBid A boolean indicating if the incoming bid is a new winning bid.
     */
    // function isNewWinningBid(
    //     uint256 _reserveAmount,
    //     uint256 _currentWinningBidAmount,
    //     uint256 _incomingBidAmount
    // ) internal view returns (bool isValidNewBid) {
    //     if (_currentWinningBidAmount == 0) {
    //         isValidNewBid = _incomingBidAmount >= _reserveAmount;
    //     } else {
    //         isValidNewBid = (_incomingBidAmount > _currentWinningBidAmount &&
    //             ((_incomingBidAmount - _currentWinningBidAmount) * MAX_BPS) /
    //                 _currentWinningBidAmount >=
    //             bidBufferBps);
    //     }
    // }

    /**
     * @dev Closes an auction.
     * If the auction hasn't started or doesn't have any bids, it is cancelled.
     * If the auction has ended, it is closed for the auction creator or the bidder.
     *
     * Emits an {AuctionClosed} event.
     *
     * Requirements:
     * - The listing must be an auction.
     * - The auction must have ended.
     *
     * @param _listingId The ID of the listing.
     * @param _closeFor The address for which to close the auction.
     */
    // function closeAuction(
    //     uint256 _listingId,
    //     address _closeFor
    // ) external override nonReentrant onlyExistingListing(_listingId) {
    //     Listing memory targetListing = listings[_listingId];

    //     if (targetListing.listingType != ListingType.Auction) {
    //         revert NotAnAuction();
    //     }

    //     Offer memory targetBid = winningBid[_listingId];

    //     // Cancel auction if (1) auction hasn't started, or (2) auction doesn't have any bids.
    //     bool toCancel = targetListing.startTime > block.timestamp ||
    //         targetBid.offeror == address(0);

    //     if (toCancel) {
    //         // cancel auction listing owner check
    //         _cancelAuction(targetListing);
    //     } else {
    //         // Need to ensure auction has ended before checking the timestamp, as we update the endtime if called before
    //         if (!(targetListing.endTime < block.timestamp)) {
    //             revert AuctionNotEnded(targetListing.endTime, block.timestamp);
    //         }

    //         // No `else if` to let auction close in 1 tx when targetListing.tokenOwner == targetBid.offeror.
    //         if (_closeFor == targetListing.tokenOwner) {
    //             _closeAuctionForAuctionCreator(targetListing, targetBid);
    //         }

    //         if (_closeFor == targetBid.offeror) {
    //             _closeAuctionForBidder(targetListing, targetBid);
    //         }
    //     }
    // }

    /**
     * @dev Closes an auction for the auction creator.
     * The auction creator receives the payout amount.
     *
     * Emits an {AuctionClosed} event.
     *
     * @param _targetListing The listing of the auction.
     * @param _winningBid The winning bid of the auction.
     */
    // function _closeAuctionForAuctionCreator(
    //     Listing memory _targetListing,
    //     Offer memory _winningBid
    // ) internal {
    //     uint256 payoutAmount = _winningBid.price;

    //     _targetListing.endTime = block.timestamp;
    //     listings[_targetListing.listingId] = _targetListing;

    //     _winningBid.price = 0;
    //     winningBid[_targetListing.listingId] = _winningBid;

    //     payout(
    //         address(this),
    //         _targetListing.tokenOwner,
    //         _targetListing.currency,
    //         payoutAmount,
    //         _targetListing
    //     );

    //     emit AuctionClosed(
    //         _targetListing.listingId,
    //         _msgSender(),
    //         false,
    //         _targetListing.tokenOwner,
    //         _winningBid.offeror
    //     );
    // }

    /**
     * @dev Closes an auction for the bidder.
     * The bidder receives the quantity of tokens they wanted.
     *
     * Emits an {AuctionClosed} event.
     *
     * @param _targetListing The listing of the auction.
     * @param _winningBid The winning bid of the auction.
     */
    // function _closeAuctionForBidder(
    //     Listing memory _targetListing,
    //     Offer memory _winningBid
    // ) internal {

    //     _targetListing.endTime = block.timestamp;

    //     winningBid[_targetListing.listingId] = _winningBid;
    //     listings[_targetListing.listingId] = _targetListing;

    //     // todo: transferListingTokens -> pure transfer (check this later)
    //     IERC721(_targetListing.assetContract).safeTransferFrom(
    //         address(this),
    //         _winningBid.offeror,
    //         _targetListing.tokenId
    //     );

    //     emit AuctionClosed(
    //         _targetListing.listingId,
    //         _msgSender(),
    //         false,
    //         _targetListing.tokenOwner,
    //         _winningBid.offeror
    //     );
    // }

    /**
     * @dev Cancels an auction.
     * The listing is deleted and the tokens are transferred back to the auction creator.
     *
     * Emits an {AuctionClosed} event.
     *
     * Requirements:
     * - The caller must be the creator of the listing.
     *
     * @param _targetListing The listing of the auction.
     */
    // function _cancelAuction(Listing memory _targetListing) internal {
    //     if (listings[_targetListing.listingId].tokenOwner != _msgSender()) {
    //         revert NotListingCreator();
    //     }

    //     _targetListing.status = ListingStatus.Cancelled;

    //     // todo: transferListingTokens -> pure transfer (check this later)
    //     IERC721(_targetListing.assetContract).safeTransferFrom(
    //         address(this),
    //         _targetListing.tokenOwner,
    //         _targetListing.tokenId
    //     );

    //     emit AuctionClosed(
    //         _targetListing.listingId,
    //         _msgSender(),
    //         true,
    //         _targetListing.tokenOwner,
    //         address(0)
    //     );
    // }

    /**
     * @dev Calculates the platform fee for a given sale price.
     * 
     * @param salePrice The sale price.
     * @return The platform fee.
     */
    function calculatePlatformFee(uint256 salePrice) public view returns (uint256) {
        return salePrice * platformFeeBps / MAX_BPS;
    }

    /**
     * @dev Handles the payout of a transaction. It first calculates the platform fee cut from the total payout amount. 
     * Then, it transfers the platform fee cut from the payer to the platform fee recipient. 
     * Finally, it transfers the remaining amount (total payout amount minus the platform fee cut) from the payer to the payee.
     *
     * Requirements:
     * - `_payer` must have sufficient balance in `_currencyToUse`.
     * - `_payee` must be able to receive `_currencyToUse`.
     *
     * @param _payer The address of the payer.
     * @param _payee The address of the payee.
     * @param _currencyToUse The address of the currency to use for the transaction.
     * @param _totalPayoutAmount The total payout amount.
     */
    function payout(
        address _payer,
        address _payee,
        address _currencyToUse,
        uint256 _totalPayoutAmount,
        Listing memory /* _listing */
    ) internal {
        uint256 platformFeeCut = calculatePlatformFee(_totalPayoutAmount);

        // Distribute price to token owner
        CurrencyTransferLib.transferCurrencyWithWrapper(
            _currencyToUse,
            _payer,
            platformFeeRecipient,
            platformFeeCut,
            NATIVE_TOKEN_WRAPPER,
            true,
            0
        );

        // Distribute the rest to the payee
        CurrencyTransferLib.transferCurrencyWithWrapper(
            _currencyToUse,
            _payer,
            _payee,
            _totalPayoutAmount - (platformFeeCut),
            NATIVE_TOKEN_WRAPPER,
            true,
            0
        );        
    }

    /**
     * @dev Validates if a token is compliant with the Story Protocol.
     * It tries to get the license token metadata for a given license token ID.
     * If the function call is successful, it checks if the license token is transferable.
     * If the function call reverts, it continues execution and returns true.
     *
     * Requirements:
     * - The `assetContract` and `tokenId` should correspond to a valid license token ID.
     *
     * param: assetContract The address of the asset contract.
     * param: tokenId The ID of the token.
     * @return isCompliant A boolean indicating if the token is compliant with the Story Protocol.
     * 
     * Note: This is not being used currenty and is a theoretical function for future versions.
     */
    function validateStoryProtocolCompliance(
        address /* assetContract */, 
        uint256 /* tokenId*/ 
        ) internal view returns (bool isCompliant) {

        // todo: get the licenseTokenId from the assetContract and tokenId
        uint256 licenseTokenId = 0; // placeholder

        bool transferable = true;
        try licenseToken.getLicenseTokenMetadata(licenseTokenId) returns (ILicenseToken.LicenseTokenMetadata memory lmt) {
            // If the function call does not revert, it was successful to check
            transferable = lmt.transferable;
        } catch {
            // If the function call reverts, continue execution
        }
        return transferable;
    }

    /**
     * @dev Validates the ownership and approval of a token.
     * If the token type is ERC721, it checks if the token owner is the owner of the token and if the token owner has approved the market for all tokens or if a specific operator is approved for the token.
     * It uses a failsafe for reverts in case of non-existent tokens.
     *
     * @param _tokenOwner The address of the token owner.
     * @param _assetContract The address of the asset contract.
     * @param _tokenId The ID of the token.
     * @return isValid A boolean indicating if the ownership and approval of the token are valid.
     */
    function validateOwnershipAndApproval(
        address _tokenOwner,
        address _assetContract,
        uint256 _tokenId
    ) internal view returns (bool isValid) {
        address market = address(this);
        address owner;
        address operator;

        // failsafe for reverts in case of non-existent tokens
        try IERC721(_assetContract).ownerOf(_tokenId) returns (address _owner) {
            owner = _owner;

            // Nesting the approval check inside this try block, to run only if owner check doesn't revert.
            // If the previous check for owner fails, then the return value will always evaluate to false.
            try IERC721(_assetContract).getApproved(_tokenId) returns (address _operator) {
                operator = _operator;
            } catch {}
        } catch {}
        isValid = owner == _tokenOwner && (operator == market || IERC721(_assetContract).isApprovedForAll(_tokenOwner, market));
    }

    /**
     * @dev Transfers listing tokens from one address to another.
     * If the token type is ERC721, it transfers the token.
     *
     * Requirements:
     * - The `_from` address must own the tokens and have approved the contract to transfer them.
     *
     * @param _from The address to transfer the tokens from.
     * @param _to The address to transfer the tokens to.
     * @param _listing The listing the tokens are associated with.
     */
    // todo alex: consider removing or changing this as no longer use 1155!!!
    // function transferListingTokens(
    //     address _from,
    //     address _to,
    //     Listing memory _listing
    // ) internal {
    //     IERC721(_listing.assetContract).safeTransferFrom(
    //         _from,
    //         _to,
    //         _listing.tokenId,
    //         ""
    //     );
    // }

    /**
     * @dev Returns the winning bid for a given listing ID.
     *
     * @param listingId The ID of the listing.
     * @return An Offer struct representing the winning bid.
     */
    function getWinningBid(uint256 listingId) external view returns (Offer memory) {
        return winningBid[listingId];
    }

    /**
     * @dev Returns the token type for a given asset contract.
     * If the asset contract supports the ERC721 interface, it returns TokenType.ERC721.
     * Otherwise, it reverts with a TokenNotSupported error.
     *
     * @param _assetContract The address of the asset contract.
     * @return tokenType The type of the token.
     */
    function getTokenType(
        address _assetContract
    ) internal view returns (TokenType tokenType) {
        if (
            IERC165(_assetContract).supportsInterface(type(IERC721).interfaceId)
        ) {
            tokenType = TokenType.ERC721;
        } else {
            revert TokenNotSupported();
        }
    }

    /**
     * @dev Returns the platform fee recipient and the platform fee in basis points.
     *
     * @return The address of the platform fee recipient and the platform fee in basis points.
     */
    function getPlatformFeeInfo() external view returns (address, uint16) {
        return (platformFeeRecipient, uint16(platformFeeBps));
    }

    /**
     * @dev Validates an existing listing.
     * It checks if the listing start time is in the past, if the listing end time is in the future, and if the token owner owns and has approved the quantity of listing tokens from the listing.
     *
     * @param _targetListing The listing to validate.
     * @return isValid A boolean indicating if the listing is valid.
     */
    // TODO ALEX: can remove this i think

    function _validateExistingListing(Listing memory _targetListing) internal view returns (bool isValid) {
        isValid =
            _targetListing.startTime <= block.timestamp &&
            _targetListing.endTime > block.timestamp &&
            validateOwnershipAndApproval(
                _targetListing.tokenOwner,
                _targetListing.assetContract,
                _targetListing.tokenId
            );
    }

    /**
     * @dev Checks if a listing is valid.
     * It validates the listing with the given ID.
     *
     * @param _listingId The ID of the listing.
     * @return isValid A boolean indicating if the listing is valid.
     */
    // TODO ALEX: can remove this i think
    function checkListingValid(uint256 _listingId) external view returns (bool isValid) {
        isValid = _validateExistingListing(listings[_listingId]);
    }

    /**
     * @dev Returns all valid listings.
     * It creates an array of all listings, counts the valid ones, and then creates a new array of valid listings.
     *
     * @return _validListings An array of valid listings.
     */
    // TODO ALEX: remove the whole thing, we shouldn't need it.
    function getAllValidListings() external view returns (Listing[] memory _validListings) {
        uint256 _startId = 0;
        uint256 _endId = totalListings - 1;

        Listing[] memory _listings = new Listing[](_endId - _startId + 1);
        uint256 _listingCount;

        for (uint256 i = _startId; i <= _endId; i += 1) {
            _listings[i - _startId] = listings[i];
            if (_validateExistingListing(_listings[i - _startId])) {
                _listingCount += 1;
            }
        }

        _validListings = new Listing[](_listingCount);
        uint256 index = 0;
        uint256 count = _listings.length;
        for (uint256 i = 0; i < count; i += 1) {
            if (_validateExistingListing(_listings[i])) {
                _validListings[index++] = _listings[i];
            }
        }
    }

    /**
     * @dev Returns a listing with a given ID.
     *
     * @param _listingId The ID of the listing.
     * @return listing The listing with the given ID.
     */
    function getListing(uint256 _listingId) external view returns (Listing memory listing) {
        listing = listings[_listingId];
    }

    /**
     * @dev Sets the platform fee recipient and the platform fee in basis points.
     * If the platform fee in basis points is greater than MAX_BPS, it reverts with an InvalidPlatformFeeBps error.
     *
     * @param _platformFeeRecipient The address of the platform fee recipient.
     * @param _platformFeeBps The platform fee in basis points.
     */
    function setPlatformFeeInfo(
        address _platformFeeRecipient,
        uint256 _platformFeeBps
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_platformFeeBps > MAX_BPS) {
            revert InvalidPlatformFeeBps();
        }

        platformFeeBps = uint64(_platformFeeBps);
        platformFeeRecipient = _platformFeeRecipient;

        emit PlatformFeeInfoUpdated(_platformFeeRecipient, _platformFeeBps);
    }

    /**
     * @dev Sets the auction time buffer and the bid buffer in basis points.
     * If the bid buffer in basis points is greater than or equal to MAX_BPS, it reverts with an InvalidBPS error.
     *
     * @param _timeBuffer The auction time buffer.
     * @param _bidBufferBps The bid buffer in basis points.
    */
    // function setAuctionBuffers(
    //     uint256 _timeBuffer,
    //     uint256 _bidBufferBps
    // ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     // Use the custom error in your function
    //     if (_bidBufferBps >= MAX_BPS) {
    //         revert InvalidBPS(_bidBufferBps, MAX_BPS);
    //     }

    //     timeBuffer = uint64(_timeBuffer);
    //     bidBufferBps = uint64(_bidBufferBps);

    //     emit AuctionBuffersUpdated(_timeBuffer, _bidBufferBps);
    // }

    /**
     * @dev Adds a token to the ERC20 whitelist.
     * If the token's total supply is 0 or less, it reverts with an InvalidERC20 error.
     *
     * @param tokenAddress The address of the token.
     */
    function erc20WhiteListAdd(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        IERC20 token = IERC20(tokenAddress);
        if (token.totalSupply() <= 0) {
            revert InvalidERC20();
        }
        
        erc20Whitelist[tokenAddress] = true;
    }

    /**
     * @dev Removes a token from the ERC20 whitelist.
     *
     * @param tokenAddress The address of the token.
     */
    function erc20WhiteListRemove(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        erc20Whitelist[tokenAddress] = false;
    }

    /**
     * @dev Overrides the default _msgSender() function to use the ERC2771Context implementation.
     * It returns the address of the sender of the message.
     *
     * @return sender The address of the sender of the message.
     */    
    function _msgSender()
        internal
        view
        override(Context, ERC2771Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev Overrides the default _msgData() function to use the ERC2771Context implementation.
     * It returns the calldata of the message.
     *
     * @return A bytes calldata representing the calldata of the message.
     */
    function _msgData()
        internal
        view
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    /**
     * @dev Overrides the default _contextContract() function to use the ERC2771Context implementation.
     * It returns the length of the context suffix.
     *
     * @return The length of the context suffix.
     */
    function _contextSuffixLength()
        internal
        view
        override(Context, ERC2771Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }
}
