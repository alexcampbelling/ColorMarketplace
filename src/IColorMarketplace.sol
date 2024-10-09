// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

interface IColorMarketplace {

    /* Enumerators */

    enum TokenType {
        ERC721
    }

    enum ListingType {
        Direct,
        Auction
    }

    enum ListingStatus { 
        Open, 
        Closed,
        Cancelled
    }

    /* Structs */

    struct ListingParameters {
        address assetContract;
        uint256 tokenId;
        uint256 startTime;
        uint256 secondsUntilEndTime;
        address currency;
        uint256 reservePrice;
        uint256 buyoutPrice;
        ListingType listingType;
    }

    struct Listing {
        uint256 listingId;
        address tokenOwner;
        address assetContract;
        uint256 tokenId;
        uint256 startTime;
        uint256 endTime;
        address currency;
        uint256 reservePrice;
        uint256 buyoutPrice;
        ListingType listingType;
        ListingStatus status;
    }

    struct Offer {
        uint256 listingId;
        address offeror;
        address currency;
        uint256 price;
        uint256 expirationTimestamp;
    }

    /* Events */

    event ReceivedEther(address sender, uint256 amount);

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
        ListingType indexed listingType,
        uint256 totalOfferAmount,
        address currency
    );

    event AuctionClosed(
        uint256 indexed listingId,
        address indexed closer,
        bool indexed cancelled,
        address auctionCreator,
        address winningBidder
    );

    event PlatformFeeInfoUpdated(
        address indexed platformFeeRecipient,
        uint256 platformFeeBps
    );

    event AuctionBuffersUpdated(uint256 timeBuffer, uint256 bidBufferBps);
    
    /* Errors */

    error NotListingOwner();
    error ListingDoesNotExist();
    error TokenNotSupported();
    error InvalidQuantity();
    error InvalidStartTime();
    error TokenNotValidOrApproved();
    error InvalidPrice();
    error ListingAlreadyStarted();
    error NotDirectListing();
    error InvalidTotalPrice();
    error InvalidTokenAmount();
    error NotWithinSaleWindow();
    error InvalidMsgValue();
    error InsufficientBalanceOrAllowance();
    error OfferExpired();
    error InactiveListing(
        uint256 startTime,
        uint256 endTime,
        uint256 currentTime
    );
    error InvalidCurrency();
    error ZeroAmountBid();
    error ValueNotNeeded();
    error NotWinningBid();
    error AuctionNotEnded(
        uint256 targetListingendTime, 
        uint256 blockTimestamp
    );
    error InvalidPlatformFeeBps();
    error InvalidBPS(uint256 bidBufferBps, uint256 maxBps);
    error InsufficientTokensInListing();
    error NoTokensInListing();
    error NotAnAuction();
    error NotListingCreator();
    error InvalidERC20();
    error TokenNotAccepted();
    error InputLengthMismatch();
    error NotStoryCompliant();
    error InvalidListingType();
    error OfferDoesNotMeetBuyoutPrice();
    error BuyoutPriceNotMet();
    error NotAuctionListing();
    error AuctionEnded();
    error BidTooLow();
    error NotInEscrow();
    error ListingNotOpen();

    /* Functions */

    function createListing(ListingParameters memory _params) external;

    function updateListing(
        uint256 _listingId,
        address _currency,
        uint256 _reservePrice,
        uint256 _buyoutPrice,
        uint256 _startTime,
        uint256 _secondsUntilEndTime
    ) external;

    function buy(
        uint256 _listingId,
        address _buyFor,
        address _currency,
        uint256 _totalPrice
    ) external payable;

    // function closeAuction(uint256 _listingId, address _closeFor) external;

    function offer(
        uint256 _listingId,
        address _currency,
        uint256 _price,
        uint256 _expirationTimestamp
    ) external payable;
    
    function acceptOffer(
        uint256 _listingId,
        address _offeror,
        address _currency,
        uint256 _price
    ) external;
}
