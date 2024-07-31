// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

interface IColorMarketplace {

    /* Enumerators */

    enum TokenType {
        ERC1155,
        ERC721
    }

    enum ListingType {
        Direct,
        Auction
    }

    enum ListingStatus { 
        Active, 
        Completed 
    }

    /* Structs */

    struct ListingParameters {
        address assetContract;
        uint256 tokenId;
        uint256 startTime;
        uint256 secondsUntilEndTime;
        uint256 quantityToList;
        address currency;
        uint256 reservePricePerToken;
        uint256 buyoutPricePerToken;
        ListingType listingType;
    }

    struct Listing {
        uint256 listingId;
        address tokenOwner;
        address assetContract;
        uint256 tokenId;
        uint256 startTime;
        uint256 endTime;
        uint256 quantity;
        address currency;
        uint256 reservePricePerToken;
        uint256 buyoutPricePerToken;
        TokenType tokenType;
        ListingType listingType;
    }

    struct Offer {
        uint256 listingId;
        address offeror;
        uint256 quantityWanted;
        address currency;
        uint256 pricePerToken;
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

    event ListingRemoved(
        uint256 indexed listingId,
        address indexed listingCreator
    );

    event NewSale(
        uint256 indexed listingId,
        address indexed assetContract,
        address indexed lister,
        address buyer,
        uint256 quantityBought,
        uint256 totalPricePaid
    );

    event NewOffer(
        uint256 indexed listingId,
        address indexed offeror,
        ListingType indexed listingType,
        uint256 quantityWanted,
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

    /* Functions */

    function createListing(ListingParameters memory _params) external;

    function updateListing(
        uint256 _listingId,
        uint256 _quantityToList,
        address _currency,
        uint256 _reservePricePerToken,
        uint256 _buyoutPricePerToken,
        uint256 _startTime,
        uint256 _secondsUntilEndTime
    ) external;

    function buy(
        uint256 _listingId,
        address _buyFor,
        uint256 _quantity,
        address _currency,
        uint256 _totalPrice
    ) external payable;

    function closeAuction(uint256 _listingId, address _closeFor) external;

    function offer(
        uint256 _listingId,
        uint256 _quantityWanted,
        address _currency,
        uint256 _pricePerToken,
        uint256 _expirationTimestamp
    ) external payable;
    
    function acceptOffer(
        uint256 _listingId,
        address _offeror,
        address _currency,
        uint256 _pricePerToken
    ) external;
}
