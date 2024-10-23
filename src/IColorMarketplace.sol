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
        RoyaltyInfo royaltyInfo;
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
        RoyaltyInfo royaltyInfo;
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
    struct RoyaltyInfo {
        address receiver;
        uint256 percentage; // In basis points (e.g., 250 = 2.5%)
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
    event ERC20WhiteListAdded(address tokenAddress);
    event ERC20WhiteListRemoved(address tokenAddress);
    event AdminCancelledListing(uint256 indexed listingId, address admin);
    event AdminCancelledOffer(uint256 indexed listingId, address indexed offeror, address admin);

    
    /* Errors */
    error NotListingOwner(address actualOwner, address caller);
    error ListingDoesNotExist(uint256 listingId);
    error InvalidStartTime(uint256 providedStartTime, uint256 currentTime);
    error TokenNotValidOrApproved(address assetContract, uint256 tokenId, address owner);
    error InvalidMsgValue(uint256 sent, uint256 expected);
    error InsufficientBalanceOrAllowance(bool isBalanceInsufficient, bool isAllowanceInsufficient);
    error OfferExpired(uint256 expirationTime, uint256 currentTime);
    error InactiveListing(uint256 startTime, uint256 endTime, uint256 currentTime);
    error ValueNotNeeded(uint256 sentValue);
    error InvalidPlatformFeeBps();
    error InvalidERC20(address tokenAddress);
    error TokenNotAccepted(address tokenAddress);
    error ListingNotOpen(uint256 listingId, ListingStatus currentStatus);
    error CurrencyMismatch(address expectedCurrency, address providedCurrency);
    error ArrayLengthMismatch(uint256 length1, uint256 length2);
    error InvalidOfferPrice();
    error OfferDoesNotExist(uint256 listingId, address offeror);
    error NotOfferor(address actualOfferor, address caller);
    error TokenNotSupported(address tokenAddress);
    error InvalidFeeRecipient();
    error StartTimeTooFarInFuture(uint256 providedStartTime, uint256 maxAllowedTime);
    error AdminTransferFailed(address newAdmin);
    error OfferNotFound(uint256 listingId, address offeror);

    /* Functions */
    // Viewing functions
    function getPlatformFeeInfo() external view returns (address, uint16);
    function getListing(uint256 _listingId) external view returns (Listing memory listing);
    function checkListingValid(uint256 _listingId) external view returns (bool isValid);
    function calculatePlatformFee(uint256 salePrice) external view returns (uint256);

    // Listing functions
    function createListing(ListingParameters memory _params) external;
    function createBatchListing(ListingParameters[] memory _paramsArray) external;
    function updateListing(
        uint256 _listingId, 
        address _currency, 
        uint256 _buyoutPrice, 
        uint256 _startTime, 
        uint256 _secondsUntilEndTime
    ) external;
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
    function setPlatformFeeInfo(address _platformFeeRecipient, uint256 _platformFeeBps) external returns (bool);
    function erc20WhiteListAdd(address tokenAddress) external returns (bool);
    function erc20WhiteListRemove(address tokenAddress) external returns (bool);
    function adminCancelListing(uint256 _listingId) external; // todo
    function adminCancelOffer(uint256 _listingId, address _offeror) external; // todo
    function transferAdminOwnership(address newAdmin) external; // todo

    // Royalty functions
    function calculateRoyaltyFee(uint256 _salePrice, RoyaltyInfo memory _royaltyInfo) external pure returns (uint256);
    function calculatePayoutDistribution(uint256 _salePrice, RoyaltyInfo memory _royaltyInfo)
        external
        view
        returns (
            uint256 platformFee,
            uint256 royaltyFee,
            uint256 sellerPayout
        );
}
