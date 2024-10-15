// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

interface IColorMarketplace {

    /* Enums */
    enum ListingStatus { Open, Closed, Cancelled }

    /* Structs */
    struct ListingParameters {
        address assetContract;
        uint256 tokenId;
        uint256 startTime;
        uint256 secondsUntilEndTime;
        address currency;
        uint256 buyoutPrice;
    }
    struct Listing {
        uint256 listingId;
        address tokenOwner;
        address assetContract;
        uint256 tokenId;
        uint256 startTime;
        uint256 endTime;
        address currency;
        uint256 buyoutPrice;
        ListingStatus status;
    }
    struct Offer {
        uint256 listingId;
        address offeror;
        address currency;
        uint256 price;
        uint256 expirationTimestamp;
    }
    struct CurrencyTotal {
        address currency;
        uint256 totalPrice;
    }

    /* Events */
    event ListingAdded(
        uint256 indexed listingId,
        address indexed assetContract,
        address indexed lister,
        Listing listing
    );
    event ListingUpdated(
        uint256 indexed listingId,
        address indexed listingCreator
    );
    event ListingCancelled(
        uint256 indexed listingId,
        address indexed listingCreator
    );
    event NewSale(
        uint256 indexed listingId,
        address indexed assetContract,
        address indexed lister,
        address buyer,
        uint256 totalPricePaid
    );
    event NewOffer(
        uint256 indexed listingId,
        address indexed offeror,
        uint256 totalOfferAmount,
        address currency
    );
    event PlatformFeeInfoUpdated(
        address indexed platformFeeRecipient,
        uint256 platformFeeBps
    );
    event OfferCancelled(
        uint256 indexed listingId, 
        address indexed offeror, 
        address currency, 
        uint256 price
    );
    
    /* Errors */
    error NotListingOwner();
    error ListingDoesNotExist();
    error InvalidStartTime();
    error TokenNotValidOrApproved();
    error InvalidPrice();
    error InvalidMsgValue(uint256 sent, uint256 expected);
    error InsufficientBalanceOrAllowance();
    error OfferExpired();
    error InactiveListing(uint256 startTime, uint256 endTime, uint256 currentTime);
    error ValueNotNeeded();
    error InvalidPlatformFeeBps();
    error InvalidERC20();
    error TokenNotAccepted();
    error ListingNotOpen();
    error CurrencyMismatch();
    error ArrayLengthMismatch(uint256 length1, uint256 length2);
    error InvalidOfferPrice();
    error OfferDoesNotExist();
    error NotOfferor();
    error TokenNotSupported();

    /* Functions */
    // Viewing functions
    function getPlatformFeeInfo() external view returns (address, uint16);
    function getListing(uint256 _listingId) external view returns (Listing memory listing);
    function checkListingValid(uint256 _listingId) external view returns (bool isValid);
    function calculatePlatformFee(uint256 salePrice) external view returns (uint256);

    // Listing functions
    function createListing(ListingParameters memory _params) external;
    function createBatchListing(ListingParameters[] memory _paramsArray) external;
    function updateListing(uint256 _listingId, address _currency, uint256 _buyoutPrice, uint256 _startTime, uint256 _secondsUntilEndTime) external;
    function cancelListing(uint256 _listingId) external;
    function cancelListings(uint256[] memory _listingIds) external;

    // Buying functions
    function buy(uint256 _listingId, address _buyFor) external payable;
    function bulkBuy(uint256[] memory _listingIds, address[] memory _buyers) external payable;

    // Offer functions
    function offer(uint256 _listingId, uint256 _price, uint256 _expirationTimestamp) external payable;
    function cancelOffer(uint256 _listingId) external;
    function acceptOffer(uint256 _listingId, address _offeror) external;

    // Admin functions
    function setPlatformFeeInfo(address _platformFeeRecipient, uint256 _platformFeeBps) external;
    function erc20WhiteListAdd(address tokenAddress) external returns (bool);
    function erc20WhiteListRemove(address tokenAddress) external;
}
