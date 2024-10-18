// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

/**
 * @title Color Marketplace
 * @author alexcampbelling
 */

/* External imports */
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* Internal imports */
import {IColorMarketplace} from "./IColorMarketplace.sol";
import {CurrencyTransferLib} from "./CurrencyTransferLib.sol";

/**
 * @title ColorMarketplace
 */
/// @custom:storage-location erc7201:colormarketplace.storage
contract ColorMarketplace is
    IColorMarketplace,
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{

    struct ColorMarketplaceStorage {
        // The address of the native token wrapper contract (equivalent to WETH)
        address NATIVE_TOKEN_WRAPPER;
        // A whitelist of ERC20 tokens that can be used in the marketplace
        mapping(address => bool) erc20Whitelist;
        // The percentage of primary sales collected as platform fees, in bps
        uint64 platformFeeBps;
        // The total number of listings ever created in the marketplace
        uint256 totalListings;
        // The address that receives the platform fees
        address platformFeeRecipient;
        // A mapping from listing UID to listing info
        mapping(uint256 => Listing) listings;
        // A mapping from listing UID to a nested mapping from offeror address to the offer they made
        mapping(uint256 => mapping(address => Offer)) offers;
        uint256 chainVersion;
    }
    uint64 public constant MAX_BPS = 10_000; // The maximum basis points (bps) value, equivalent to 100%

    bytes32 private constant STORAGE_LOCATION = keccak256("colormarketplace.storage");

    function _getStorage() internal pure returns (ColorMarketplaceStorage storage $) {
        bytes32 position = STORAGE_LOCATION;
        assembly {
            $.slot := position
        }
    }

    /* Initialization Functions */

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function initialize(
        address _nativeTokenWrapper,
        address _defaultAdmin,
        address _platformFeeRecipient,
        uint256 _platformFeeBps,
        address[] memory _erc20Whitelist
    ) public initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        ColorMarketplaceStorage storage $ = _getStorage();

        $.NATIVE_TOKEN_WRAPPER = _nativeTokenWrapper;
        $.platformFeeBps = uint64(_platformFeeBps);
        $.platformFeeRecipient = _platformFeeRecipient;
        
        for (uint i = 0; i < _erc20Whitelist.length; i++) {
            $.erc20Whitelist[_erc20Whitelist[i]] = true;
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

        $.chainVersion = 1;
    }

    /**
     * @dev Ensures that the contract doesn't accidentally receive native tokens, locking them
     */
    receive() external payable {
        revert("Direct Ether transfers not accepted");
    }

    /* External View Functions */

    /**
     * @dev Returns the platform fee recipient and the platform fee in basis points.
     *
     * @return The address of the platform fee recipient and the platform fee in basis points.
     */
    function getPlatformFeeInfo() external view returns (address, uint16) {
        ColorMarketplaceStorage storage $ = _getStorage();
        return ($.platformFeeRecipient, uint16($.platformFeeBps));
    }

    /**
     * @dev Checks if a listing is valid.
     * It validates the listing with the given ID.
     *
     * @param _listingId The ID of the listing.
     * @return isValid A boolean indicating if the listing is valid.
     */
    function checkListingValid(uint256 _listingId) external view returns (bool isValid) {
        ColorMarketplaceStorage storage $ = _getStorage();
        Listing memory listing = $.listings[_listingId];
        return _isListingValid(listing);
    }

    /* External State-Changing Functions */

    /**
     * @dev Creates a new listing on the marketplace.
     *
     * This is an external facing method that creates a Listing.
     * Logic for listing is found in internal _createListing function.
     * 
     * Modifiers:
     * - onlyWhitelistedErc20s(_params.currency)
     *
     * @param _params The parameters for the listing. See IColorMarketplace.sol for more details.
     */
    function createListing(ListingParameters memory _params) 
        external 
        override onlyWhitelistedErc20s(_params.currency)
    {
        _createListing(_params);
    }

    /**
     * @dev Creates multiple new listings on the marketplace.
     *
     * This is an external facing method that creates a batch amount of Listings.
     * 
     * Modifers:
     *  - onlyWhitelistedErc20sBatch(_extractCurrencies(_paramsArray))
     * 
     * @param _paramsArray An array of parameters for the listings.
     */
    function createBatchListing(ListingParameters[] memory _paramsArray) 
        external 
        onlyWhitelistedErc20sBatch(_extractCurrencies(_paramsArray))
    {
        for (uint256 i = 0; i < _paramsArray.length; i++) {
            _createListing(_paramsArray[i]);
        }
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
     *
     * @param _listingId The ID of the listing to update.
     * @param _currency The new currency for the listing.
     * @param _buyoutPrice The new buyout price for token.
     * @param _startTime The new start time for the listing.
     * @param _secondsUntilEndTime The new number of seconds until the end time.
     */
    function updateListing(
        uint256 _listingId,
        address _currency,
        uint256 _buyoutPrice,
        uint256 _startTime,
        uint256 _secondsUntilEndTime,
        RoyaltyInfo memory _royaltyInfo
    ) onlyWhitelistedErc20s(_currency) external override onlyListingCreator(_listingId) {
        ColorMarketplaceStorage storage $ = _getStorage();
        Listing memory targetListing = $.listings[_listingId];

        if (targetListing.status != ListingStatus.Open) {
            revert ListingNotOpen();
        }

        _startTime = _validateAndAdjustStartTime(_startTime);

        uint256 newStartTime = _startTime == 0
            ? targetListing.startTime
            : _startTime;

        $.listings[_listingId] = Listing({
            listingId: _listingId,
            tokenOwner: _msgSender(),
            assetContract: targetListing.assetContract,
            tokenId: targetListing.tokenId,
            startTime: newStartTime,
            endTime: _secondsUntilEndTime == 0
                ? targetListing.endTime
                : newStartTime + _secondsUntilEndTime,
            currency: _currency,
            buyoutPrice: _buyoutPrice,
            status: ListingStatus.Open,
            royaltyInfo: _royaltyInfo
        });

        // Validate ownership and approval for the token
        if (!validateOwnershipAndApproval(
            targetListing.tokenOwner,
            targetListing.assetContract,
            targetListing.tokenId
        )) {
            revert TokenNotValidOrApproved();
        }

        emit ListingUpdated(_listingId, targetListing.tokenOwner);
    }

    /**
     * @dev Cancels a listing on the marketplace.
     *
     * This function allows the creator of a listing to cancel it. 
     * It first checks if the listing is a listing, and if it is, 
     * it deletes the listing and emits a {ListingRemoved} event.
     *
     * Requirements:
     * - `msg.sender` must be the creator of the listing.
     *
     * @param _listingId The ID of the listing to cancel.
     */
    function cancelListing(
        uint256 _listingId
    ) public onlyListingCreator(_listingId) {
        ColorMarketplaceStorage storage $ = _getStorage();
        Listing memory targetListing = $.listings[_listingId];

        if (targetListing.status != ListingStatus.Open) {
            revert ListingNotOpen();
        }

        $.listings[_listingId].status = ListingStatus.Cancelled;

        emit ListingCancelled(_listingId, targetListing.tokenOwner);
    }

    /**
     * @dev Cancels multiple listings on the marketplace.
     *
     * This function allows the caller to cancel multiple listings at once. It takes an array of listing IDs as input,
     * and for each ID in the array, it calls the `cancelListing` function.
     *
     * @param _listingIds An array of the IDs of the listings to cancel.
     */
    function cancelListings(
        uint256[] memory _listingIds
    ) external {
        for (uint256 i = 0; i < _listingIds.length; i++) {
            cancelListing(_listingIds[i]);
        }
    }

    /**
     * @dev Buys a listing on the marketplace.
     *
     * This function is a public wrapper for the `_buy` function. It is necessary to prevent reentry attacks,
     * but it can still be called with bulk buys.
     *
     * @param _listingId The ID of the listing to buy.
     * @param _buyFor The address to buy the listing for.
     */    
    function buy(
        uint256 _listingId,
        address _buyFor
    ) external payable nonReentrant onlyExistingListing(_listingId) {
        _buy(_listingId, _buyFor);
    }

    /**
     * @dev Executes a bulk buy operation.
     * @param _listingIds An array of listing IDs to buy.
     * @param _buyers An array of addresses to buy the listings for.
     */
    function bulkBuy(uint256[] memory _listingIds, address[] memory _buyers) 
        external 
        payable 
        nonReentrant 
    {
        ColorMarketplaceStorage storage $ = _getStorage();
        if (_listingIds.length != _buyers.length) {
            revert ArrayLengthMismatch(_listingIds.length, _buyers.length);
        }
        
        address payer = _msgSender();
        validateBulkBuy(_listingIds, payer);

        for (uint256 i = 0; i < _listingIds.length; i++) {
            Listing memory listing = $.listings[_listingIds[i]];
            executeSale(
                listing,
                payer,
                _buyers[i],
                listing.currency,
                listing.buyoutPrice
            );
        }
    }

    /**
     * @dev Allows an account to make an offer to a listing.
     *
     * @param _listingId The ID of the listing to make the offer or bid to.
     * @param _price The price for token of the offer or bid.
     * @param _expirationTimestamp The expiration timestamp of the offer or bid.
     */    
    function offer(
        uint256 _listingId,
        uint256 _price,
        uint256 _expirationTimestamp
    ) external payable override nonReentrant onlyExistingListing(_listingId) {
        ColorMarketplaceStorage storage $ = _getStorage();
        if (_price == 0) {
            revert InvalidOfferPrice();
        }
        Listing memory targetListing = $.listings[_listingId];

        // Validate the listing and the offer
        validateSingularSale(targetListing, _msgSender(), _price, targetListing.currency);

        Offer memory newOffer = Offer({
            listingId: _listingId,
            offeror: _msgSender(),
            currency: targetListing.currency,
            price: _price,
            expirationTimestamp: _expirationTimestamp
        });

        // Prevent potentially lost/locked native token.
        if (msg.value != 0) {
            revert ValueNotNeeded();
        }

        handleOffer(targetListing, newOffer);
    }

    /**
     * @dev Allows an offeror to cancel their own offer for a listing.
     * @param _listingId The ID of the listing for which the offer was made.
     */
    function cancelOffer(uint256 _listingId) external nonReentrant {
        ColorMarketplaceStorage storage $ = _getStorage();
        Offer memory existingOffer = $.offers[_listingId][_msgSender()];
        
        // Check if the offer exists
        if (existingOffer.offeror == address(0)) {
            revert OfferDoesNotExist();
        }

        // Check if the caller is the offeror
        if (existingOffer.offeror != _msgSender()) {
            revert NotOfferor();
        }

        // Delete the offer
        delete $.offers[_listingId][_msgSender()];

        // Emit an event for the cancelled offer
        emit OfferCancelled(_listingId, _msgSender(), existingOffer.currency, existingOffer.price);
    }

    /**
     * @dev Accepts an offer for a listing on the marketplace.
     *
     * This function allows the creator of a listing to accept an offer for it. It first checks if the offer's currency
     * and price per token are correct, and if the offer has not expired. If all checks pass, it deletes the offer and executes
     * the sale.
     *
     * @param _listingId The ID of the listing to accept the offer for.
     * @param _offeror The address of the offeror.
     */    
    function acceptOffer(
        uint256 _listingId,
        address _offeror
    )
        external
        override
        nonReentrant
        onlyListingCreator(_listingId)
        onlyExistingListing(_listingId)
    {
        ColorMarketplaceStorage storage $ = _getStorage();
        Offer memory targetOffer = $.offers[_listingId][_offeror];

        // Check if the offer exists
        if (targetOffer.offeror == address(0)) {
            revert OfferDoesNotExist();
        }

        Listing memory targetListing = $.listings[_listingId];
        
        // Offer may have expired by the time the listed attempts to accept this!
        if (targetOffer.expirationTimestamp <= block.timestamp) {
            revert OfferExpired();
        }

        // Verify the sale could go through
        validateSingularSale(
            targetListing, 
            _offeror, 
            targetOffer.price, 
            targetOffer.currency
        );

        // Start mutating state now checks are done
        delete $.offers[_listingId][_offeror];

        executeSale(
            targetListing,
            _offeror,
            _offeror,
            targetOffer.currency,
            targetOffer.price
        );
    }

    /**
     * @dev Sets the platform fee recipient and the platform fee in basis points.
     * If the platform fee in basis points is greater than MAX_BPS, it reverts with an InvalidPlatformFeeBps error.
     *
     * @param _platformFeeRecipient The address of the platform fee recipient.
     * @param _platformFeeBps The platform fee in basis points.
     */
    function setPlatformFeeInfo(address _platformFeeRecipient, uint256 _platformFeeBps) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns (bool)
    {
        ColorMarketplaceStorage storage $ = _getStorage();

        if (_platformFeeBps > 10000) {
            revert InvalidPlatformFeeBps();
        }

        if (_platformFeeRecipient == address(0)) {
            revert InvalidFeeRecipient();
        }

        if ($.platformFeeRecipient == _platformFeeRecipient && $.platformFeeBps == _platformFeeBps) {
            return false; // No changes made
        }

        $.platformFeeRecipient = _platformFeeRecipient;
        $.platformFeeBps = uint64(_platformFeeBps);

        emit PlatformFeeInfoUpdated(_platformFeeRecipient, _platformFeeBps);
        return true;
    }

    /**
     * @dev Adds a token to the ERC20 whitelist.
     * If the token's total supply is 0 or less, it reverts with an InvalidERC20 error.
     *
     * @param tokenAddress The address of the token.
     */
    function erc20WhiteListAdd(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        ColorMarketplaceStorage storage $ = _getStorage();
        IERC20 token = IERC20(tokenAddress);
        if ($.erc20Whitelist[tokenAddress]) {
            return false; // Token is already whitelisted
        }
        if (token.totalSupply() <= 0) {
            revert InvalidERC20();
        }
        
        $.erc20Whitelist[tokenAddress] = true;
        emit ERC20WhiteListAdded(tokenAddress);
        return true;
    }

    /**
     * @dev Removes a token from the ERC20 whitelist.
     *
     * @param tokenAddress The address of the token.
     */
    function erc20WhiteListRemove(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool){
        ColorMarketplaceStorage storage $ = _getStorage();
        if (!$.erc20Whitelist[tokenAddress]) {
            return false; // Token is not whitelisted
        }
        $.erc20Whitelist[tokenAddress] = false;
        emit ERC20WhiteListRemoved(tokenAddress);
        return true;
    }

    /* Public View Functions */

    /**
     * @dev Calculates the platform fee for a given sale price.
     * 
     * @param salePrice The sale price.
     * @return The platform fee.
     */
    function calculatePlatformFee(uint256 salePrice) public view returns (uint256) {
        ColorMarketplaceStorage storage $ = _getStorage();
        return salePrice * $.platformFeeBps / MAX_BPS;
    }

    function calculateRoyaltyFee(uint256 _salePrice, RoyaltyInfo memory _royaltyInfo) public pure returns (uint256) {
        return (_salePrice * _royaltyInfo.percentage) / 10000;
    }

    function calculatePayoutDistribution(uint256 _salePrice, RoyaltyInfo memory _royaltyInfo)
        public
        view
        returns (
            uint256 platformFee,
            uint256 royaltyFee,
            uint256 sellerPayout
        )
    {
        platformFee = calculatePlatformFee(_salePrice);
        royaltyFee = calculateRoyaltyFee(_salePrice, _royaltyInfo);
        sellerPayout = _salePrice - (platformFee + royaltyFee);
        return (platformFee, royaltyFee, sellerPayout);
    }

    /* Internal View Functions */

    /**
     * @dev Validates the base conditions of a listing.
     * @param listing The listing to validate.
     */
    function validateListingBase(Listing memory listing) internal view {
        // Check if the listing is open
        if (listing.status != ListingStatus.Open) {
            revert ListingNotOpen();
        }

        // Check if the listing is active (within start and end time)
        if (block.timestamp < listing.startTime || block.timestamp >= listing.endTime) {
            revert InactiveListing(listing.startTime, listing.endTime, block.timestamp);
        }

        // Verify token ownership and approval for the lister
        if (!validateOwnershipAndApproval(
            listing.tokenOwner,
            listing.assetContract,
            listing.tokenId
        )) {
            revert TokenNotValidOrApproved();
        }
    }

    function _isListingValid(Listing memory listing) internal view returns (bool) {
        if (listing.status != ListingStatus.Open) {
            return false;
        }

        if (block.timestamp < listing.startTime || block.timestamp >= listing.endTime) {
            return false;
        }

        if (!validateOwnershipAndApproval(
            listing.tokenOwner,
            listing.assetContract,
            listing.tokenId
        )) {
            return false;
        }

        return true;
    }

    /**
     * @dev Validates the currency amount for a user.
     * @param user The address of the user.
     * @param currency The address of the currency token.
     * @param amount The amount to validate.
     */
    function validateCurrency(address user, address currency, uint256 amount) internal view {
        if (currency == CurrencyTransferLib.NATIVE_TOKEN) {
            // For native token, check if the sent value matches the required amount
            if (msg.value != amount) {
                revert InvalidMsgValue(msg.value, amount);
            }
        } else {
            // For ERC20 tokens, check balance and allowance
            validateERC20BalAndAllowance(user, currency, amount);
        }
    }

    /**
     * @dev Validates a singular sale (used for buy and acceptOffer).
     * @param listing The listing to validate.
     * @param buyer The address of the buyer.
     * @param price The price to validate against.
     * @param currency The currency to use for the transaction.
     */
    function validateSingularSale(Listing memory listing, address buyer, uint256 price, address currency) internal view {
        validateListingBase(listing);
        
        // Check if the currency matches the listing currency
        if (listing.currency != currency) {
            revert CurrencyMismatch();
        }

        validateCurrency(buyer, currency, price);
    }

    /**
     * @dev Validates a bulk buy operation.
     * @param listingIds An array of listing IDs to validate.
     * @param buyer The address of the buyer.
     */
    function validateBulkBuy(uint256[] memory listingIds, address buyer) internal view {
        ColorMarketplaceStorage storage $ = _getStorage();
        uint256 totalNativeValue = 0;
        CurrencyTotal[] memory currencyTotals = new CurrencyTotal[](listingIds.length);
        uint256 uniqueCurrencyCount = 0;

        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing memory listing = $.listings[listingIds[i]];
            validateListingBase(listing);

            // Accumulate total prices per currency
            if (listing.currency == CurrencyTransferLib.NATIVE_TOKEN) {
                totalNativeValue += listing.buyoutPrice;
            } else {
                bool found = false;
                for (uint256 j = 0; j < uniqueCurrencyCount; j++) {
                    if (currencyTotals[j].currency == listing.currency) {
                        currencyTotals[j].totalPrice += listing.buyoutPrice;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    currencyTotals[uniqueCurrencyCount] = CurrencyTotal(listing.currency, listing.buyoutPrice);
                    uniqueCurrencyCount++;
                }
            }
        }

        // Validate native token amount
        if (msg.value != totalNativeValue) {
            revert InvalidMsgValue(msg.value, totalNativeValue);
        }

        // Validate ERC20 token amounts
        for (uint256 i = 0; i < uniqueCurrencyCount; i++) {
            validateERC20BalAndAllowance(buyer, currencyTotals[i].currency, currencyTotals[i].totalPrice);
        }
    }

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

    /* Internal State-Changing Functions */

    /**
     * @dev Creates a new listing on the marketplace.
     *
     * This is an internal function that is called by `createListing` and `createBatchListing`.
     * It collates all the necessary data for the listing, validates the ownership and approval of the token(s),
     * and creates a new `Listing` struct.
     *
     * Emits a {ListingAdded} event.
     *
     * Requirements:
     * - `msg.sender` must be the owner of the NFT.
     * - The currency of the listing must be whitelisted.
     * - The listing must not start in the past.
     * - The token must be valid and approved for transfer.
     *
     * @param _params The parameters for the listing.
     */
    function _createListing(ListingParameters memory _params) 
        internal 
    {
        ColorMarketplaceStorage storage $ = _getStorage();
        // Collate all listing data
        uint256 listingId = $.totalListings;
        $.totalListings += 1;
        address tokenOwner = _msgSender();
        uint256 startTime = _validateAndAdjustStartTime(_params.startTime);

        if (!validateOwnershipAndApproval(
            tokenOwner,
            _params.assetContract,
            _params.tokenId
        )) {
            revert TokenNotValidOrApproved();
        }

        // Check if royalty info is valid, if not set known null values
        // Set royalty as 0 address if nothing is set
        RoyaltyInfo memory royaltyInfo = _params.royaltyInfo.receiver == address(0) 
            ? RoyaltyInfo(address(0), 0) 
            : _params.royaltyInfo;

        Listing memory newListing = Listing({
            listingId: listingId,
            tokenOwner: tokenOwner,
            assetContract: _params.assetContract,
            tokenId: _params.tokenId,
            startTime: startTime,
            endTime: startTime + _params.secondsUntilEndTime,
            currency: _params.currency,
            buyoutPrice: _params.buyoutPrice,
            status: ListingStatus.Open,
            royaltyInfo: royaltyInfo
        });

        $.listings[listingId] = newListing;

        emit ListingAdded(
            listingId,
            _params.assetContract,
            tokenOwner,
            newListing
        );
    }

    /**
     * @dev Buys a listing on the marketplace.
     *
     * This function is the internal implementation of the `buy` function. It checks whether the settled total price
     * and currency to use are correct, and if they are, it executes the sale.
     *
     * @param _listingId The ID of the listing to buy.
     * @param _buyFor The address to buy the listing for.
     */
    function _buy(
        uint256 _listingId,
        address _buyFor
    ) internal {
        ColorMarketplaceStorage storage $ = _getStorage();
        Listing memory targetListing = $.listings[_listingId];
        address payer = _msgSender();

        validateSingularSale(
            targetListing, 
            payer, 
            targetListing.buyoutPrice, 
            targetListing.currency);

        executeSale(
            targetListing,
            payer,
            _buyFor,
            targetListing.currency,
            targetListing.buyoutPrice
        );
    }

    function executeSale(
        Listing memory _targetListing,
        address _payer,
        address _receiver,
        address _currency,
        uint256 _currencyAmountToTransfer
    ) internal {
        ColorMarketplaceStorage storage $ = _getStorage();
        // 1. Update listing status
        $.listings[_targetListing.listingId].status = ListingStatus.Closed;

        // 2. Payout transaction with fees
        payout(
            _payer,
            _targetListing.tokenOwner,
            _currency,
            _currencyAmountToTransfer,
            _targetListing.royaltyInfo
        );

        // 3. Transfer tokens
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


    /* Private Functions */

    // Helper function to extract currencies from ListingParameters array
    function _extractCurrencies(ListingParameters[] memory _paramsArray) 
        internal 
        pure 
        returns (address[] memory) 
    {
        address[] memory currencies = new address[](_paramsArray.length);
        for (uint256 i = 0; i < _paramsArray.length; i++) {
            currencies[i] = _paramsArray[i].currency;
        }
        return currencies;
    }

    /**
     * @dev Validates and adjusts the start time for a listing.
     * 
     * This function ensures that the start time is not too far in the past.
     * If the start time is in the past but within the allowed buffer (1 hour),
     * it adjusts the start time to the current timestamp.
     *
     * Requirements:
     * - The start time must not be more than 1 hour in the past
     *
     * @param _startTime The proposed start time for the listing
     * @return uint256 The validated and potentially adjusted start time
     *
     * @custom:throws InvalidStartTime if the start time is more than 1 hour in the past
     */
    function _validateAndAdjustStartTime(uint256 _startTime) internal view returns (uint256) {
        if (_startTime < block.timestamp) {
            // Do not allow listing to start more than 1 hour in the past
            if (block.timestamp - _startTime > 1 hours) {
                revert InvalidStartTime();
            }
            return block.timestamp;
        }
        return _startTime;
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
        RoyaltyInfo memory _royaltyInfo
    ) private {
        ColorMarketplaceStorage storage $ = _getStorage();
        uint256 platformFeeCut = calculatePlatformFee(_totalPayoutAmount);
        uint256 royaltyCut = _royaltyInfo.receiver != address(0) 
            ? calculateRoyaltyFee(_totalPayoutAmount, _royaltyInfo) 
            : 0;

        // Distribute platform fee cut
        CurrencyTransferLib.transferCurrencyWithWrapper(
            _currencyToUse,
            _payer,
            $.platformFeeRecipient,
            platformFeeCut,
            $.NATIVE_TOKEN_WRAPPER,
            true,
            0
        );

        // Distribute royalty cut
        if (royaltyCut > 0) {
            CurrencyTransferLib.transferCurrencyWithWrapper(
                _currencyToUse,
                _payer,
                _royaltyInfo.receiver,
                royaltyCut,
                $.NATIVE_TOKEN_WRAPPER,
                true,
                0
            );
        }

        // Distribute the rest to the payee
        CurrencyTransferLib.transferCurrencyWithWrapper(
            _currencyToUse,
            _payer,
            _payee,
            _totalPayoutAmount - (platformFeeCut + royaltyCut),
            $.NATIVE_TOKEN_WRAPPER,
            true,
            0
        );        
    }

    /**
     * @dev Handles an offer made to a listing.
     * Validates the offer and updates the offers mapping.
     *
     * Emits a {NewOffer} event.
     *
     * Requirements:
     * - The offeror must have sufficient ERC20 balance and allowance.
     *
     * @param _targetListing The listing to which the offer is made.
     * @param _newOffer The offer being made.
     */
    function handleOffer(
        Listing memory _targetListing,
        Offer memory _newOffer
    ) private {
        ColorMarketplaceStorage storage $ = _getStorage();
        $.offers[_targetListing.listingId][_newOffer.offeror] = _newOffer;

        emit NewOffer(
            _targetListing.listingId,
            _newOffer.offeror,
            _newOffer.price,
            _newOffer.currency
        );
    }

    /**
     * @dev Validates the ownership and approval of a token.
     * If the token type is ERC721, it checks if the token owner is the owner of the token and if the token owner has approved the market for all tokens or if a specific operator is approved for the token.
     * It uses a failsafe for reverts in case of non-existent token.
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
    ) private view returns (bool isValid) {
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
     * @dev Validates an existing listing.
     * It checks if the listing start time is in the past, if the listing end time is in the future, 
     * and if the token owner owns the listing token.
     *
     * @param _targetListing The listing to validate.
     * @return isValid A boolean indicating if the listing is valid.
     */

    function _validateExistingListing(Listing memory _targetListing) private view returns (bool isValid) {
        // @dev: status check here would be nice, but need to consider edge cases where it is not valid but status is good
        isValid =
            _targetListing.startTime <= block.timestamp &&
            _targetListing.endTime > block.timestamp &&
            validateOwnershipAndApproval(
                _targetListing.tokenOwner,
                _targetListing.assetContract,
                _targetListing.tokenId
            );
    }

    /* Modifier Functions */

    /**
     * @dev Ensures the token is either the native token or a whitelisted ERC20 token.
     *
     * Requirements:
     * - `tokenAddress` must be either the native token identifer or a token in the `erc20Whitelist`.
     *
     * @param tokenAddress The address of the token.
     */
    modifier onlyWhitelistedErc20s(address tokenAddress) {
        ColorMarketplaceStorage storage $ = _getStorage();
        if (tokenAddress != CurrencyTransferLib.NATIVE_TOKEN && !$.erc20Whitelist[tokenAddress]) {
            revert TokenNotAccepted();
        }
        _;
    }

    modifier onlyWhitelistedErc20sBatch(address[] memory tokenAddresses) {
        ColorMarketplaceStorage storage $ = _getStorage();
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if (tokenAddresses[i] != CurrencyTransferLib.NATIVE_TOKEN && !$.erc20Whitelist[tokenAddresses[i]]) {
                revert TokenNotAccepted();
            }
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
        ColorMarketplaceStorage storage $ = _getStorage();
        if ($.listings[_listingId].tokenOwner != _msgSender()) {
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
        ColorMarketplaceStorage storage $ = _getStorage();
        if ($.listings[_listingId].assetContract == address(0)) {
            revert ListingDoesNotExist();
        }
        _;
    }

    /* Getters for storage variables */

    function chainVersion() public view returns (uint256) {
        ColorMarketplaceStorage storage $ = _getStorage();
        return $.chainVersion;
    }

    function getNativeTokenWrapper() public view returns (address) {
        return _getStorage().NATIVE_TOKEN_WRAPPER;
    }

    function isErc20Whitelisted(address token) public view returns (bool) {
        return _getStorage().erc20Whitelist[token];
    }

    function getPlatformFeeBps() public view returns (uint64) {
        return _getStorage().platformFeeBps;
    }

    function getTotalListings() public view returns (uint256) {
        return _getStorage().totalListings;
    }

    function getPlatformFeeRecipient() public view returns (address) {
        return _getStorage().platformFeeRecipient;
    }

    function getListing(uint256 listingId) public view returns (Listing memory) {
        return _getStorage().listings[listingId];
    }

    function getOffer(uint256 listingId, address offeror) public view returns (Offer memory) {
        return _getStorage().offers[listingId][offeror];
    }
}
