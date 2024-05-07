// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

/**
 * @title Color Marketplace (v1.0-alpha-2)
 * @author alexcampbelling
 * @custom:experimental This is an experimental and unfinished contract.
 * @custom:cite This is based off MarketplaceV3 from thirdweb.com
 */

/* External imports */

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* Internal imports */

import "./IColorMarketplace.sol";
import "./CurrencyTransferLib.sol";

contract ColorMarketplace is
    IColorMarketplace,
    ReentrancyGuard,
    ERC2771Context,
    AccessControl,
    Initializable,
    IERC721Receiver,
    IERC1155Receiver
{
    /* Hard coded for testing purposes */
    // todo: remove this assumption that native token is the 0 address, as they don't have one tbh!
    address public _currencyToAccept =
        0x0000000000000000000000000000000000000000;

    /* State variables */

    string public constant NAME = "Color Marketplace";
    string public constant VERSION = "1.0.0-alpha-2";

    /// @dev The address of the native token wrapper contract. (WETH basically)
    address private immutable NATIVE_TOKEN_WRAPPER;

    /// @dev Total number of listings ever created in the marketplace.
    uint256 public totalListings;

    /// @dev The address of the platform fee recipient.
    address private platformFeeRecipient; // todo: check we want this

    /// @dev The max bps of the contract. So, 10_000 == 100 %
    uint64 public constant MAX_BPS = 10_000;

    /// @dev The % of primary sales collected as platform fees.
    uint64 private platformFeeBps;

    /**
     *  @dev The amount of time added to an auction's 'endTime', if a bid is made within `timeBuffer`
     *       seconds of the existing `endTime`. Default: 15 minutes.
     */
    uint64 public timeBuffer;

    /// @dev The minimum % increase required from the previous winning bid. Default: 5%.
    uint64 public bidBufferBps; // todo: investigate more

    /* Mappings */

    /// @dev Mapping from uid of listing => listing info.
    mapping(uint256 => Listing) public listings;

    /// @dev Mapping from uid of a direct listing => offeror address => offer made to the direct listing by the respective offeror.
    mapping(uint256 => mapping(address => Offer)) public offers;

    /// @dev Mapping from uid of an auction listing => current winning bid in an auction.
    mapping(uint256 => Offer) public winningBid;

    /* Modifiers */

    modifier onlyListingCreator(uint256 _listingId) {
        if (listings[_listingId].tokenOwner != _msgSender()) {
            revert NotListingOwner();
        }
        _;
    }

    /// @dev Checks whether a listing exists.
    modifier onlyExistingListing(uint256 _listingId) {
        // todo: is this the most clear way of doign this?
        if (listings[_listingId].assetContract == address(0)) {
            revert DoesNotExist();
        }
        _;
    }

    /* Constructor */
    // todo: Correctly init a trusted meta transaction address for checking forwards.
    // constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {}
    // constructor(address _nativeTokenWrapper) initializer {
    //     nativeTokenWrapper = _nativeTokenWrapper;
    // }

    constructor(
        address trustedForwarder,
        address _nativeTokenWrapper
    ) ERC2771Context(trustedForwarder) initializer {
        NATIVE_TOKEN_WRAPPER = _nativeTokenWrapper;
    }

    function initialize(
        address _defaultAdmin,
        address _platformFeeRecipient,
        uint256 _platformFeeBps
    ) external initializer {
        // todo: check that inherited contracts are correctly set up
        // - reentryguard is up
        // - erc2771 trusted forwarders is set up

        // Initialize this contract's state.
        timeBuffer = 15 minutes;
        bidBufferBps = 500;

        platformFeeBps = uint64(_platformFeeBps);
        platformFeeRecipient = _platformFeeRecipient;

        // Grant the DEFAULT_ADMIN_ROLE to the _defaultAdmin address.
        grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    /// @dev Lets the contract receives native tokens from `nativeTokenWrapper` withdraw.
    // todo: check this logic
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /* Receiving 165 721 1155 logic */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /* Listing logic */

    function createListing(ListingParameters memory _params) external override {
        // Collate all lisiting data
        uint256 listingId = totalListings;
        totalListings += 1;
        address tokenOwner = _msgSender();
        TokenType tokenTypeOfListing = getTokenType(_params.assetContract);
        uint256 tokenAmountToList = getSafeQuantity(
            tokenTypeOfListing,
            _params.quantityToList
        );

        if (tokenAmountToList <= 0) {
            revert InvalidQuantity();
        }

        uint256 startTime = _params.startTime;

        if (startTime < block.timestamp) {
            // do not allow listing to start in the past (1 hour buffer)
            if (block.timestamp - startTime < 1 hours) {
                revert InvalidStartTime();
            }
            startTime = block.timestamp;
        }

        validateOwnershipAndApproval(
            tokenOwner,
            _params.assetContract,
            _params.tokenId,
            tokenAmountToList,
            tokenTypeOfListing
        );

        Listing memory newListing = Listing({
            listingId: listingId,
            tokenOwner: tokenOwner,
            assetContract: _params.assetContract,
            tokenId: _params.tokenId,
            startTime: startTime,
            endTime: startTime + _params.secondsUntilEndTime,
            quantity: tokenAmountToList,
            currency: _currencyToAccept,
            reservePricePerToken: _params.reservePricePerToken,
            buyoutPricePerToken: _params.buyoutPricePerToken,
            tokenType: tokenTypeOfListing,
            listingType: _params.listingType
        });

        listings[listingId] = newListing;

        // Tokens listed for sale in an auction are escrowed in Marketplace.
        if (newListing.listingType == ListingType.Auction) {
            // todo: sanity check this
            if (
                newListing.buyoutPricePerToken != 0 &&
                newListing.buyoutPricePerToken < newListing.reservePricePerToken
            ) {
                revert InvalidPrice();
            }
            transferListingTokens(
                tokenOwner,
                address(this),
                tokenAmountToList,
                newListing
            );
        }

        emit ListingAdded(
            listingId,
            _params.assetContract,
            tokenOwner,
            newListing
        );
    }

    function updateListing(
        uint256 _listingId,
        uint256 _quantityToList,
        uint256 _reservePricePerToken,
        uint256 _buyoutPricePerToken,
        uint256 _startTime,
        uint256 _secondsUntilEndTime
    ) external override onlyListingCreator(_listingId) {
        Listing memory targetListing = listings[_listingId];
        uint256 safeNewQuantity = getSafeQuantity(
            targetListing.tokenType,
            _quantityToList
        );
        bool isAuction = targetListing.listingType == ListingType.Auction;

        if (safeNewQuantity == 0) {
            revert InvalidQuantity();
        }

        // Can only edit auction listing before it starts.
        if (isAuction) {
            if (block.timestamp >= targetListing.startTime) {
                revert ListingAlreadyStarted();
            }

            if (
                _buyoutPricePerToken != 0 &&
                _buyoutPricePerToken < _reservePricePerToken
            ) {
                revert InvalidPrice();
            }
        }

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
            quantity: safeNewQuantity,
            currency: _currencyToAccept,
            reservePricePerToken: _reservePricePerToken,
            buyoutPricePerToken: _buyoutPricePerToken,
            tokenType: targetListing.tokenType,
            listingType: targetListing.listingType
        });

        // Must validate ownership and approval of the new quantity of tokens for direct listing.
        if (targetListing.quantity != safeNewQuantity) {
            // Transfer all escrowed tokens back to the lister, to be reflected in the lister's
            // balance for the upcoming ownership and approval check.
            if (isAuction) {
                transferListingTokens(
                    address(this),
                    targetListing.tokenOwner,
                    targetListing.quantity,
                    targetListing
                );
            }

            validateOwnershipAndApproval(
                targetListing.tokenOwner,
                targetListing.assetContract,
                targetListing.tokenId,
                safeNewQuantity,
                targetListing.tokenType
            );

            // Escrow the new quantity of tokens to list in the auction.
            if (isAuction) {
                transferListingTokens(
                    targetListing.tokenOwner,
                    address(this),
                    safeNewQuantity,
                    targetListing
                );
            }
        }

        emit ListingUpdated(_listingId, targetListing.tokenOwner);
    }

    function cancelDirectListing(
        uint256 _listingId
    ) external onlyListingCreator(_listingId) {
        Listing memory targetListing = listings[_listingId];

        if (targetListing.listingType != ListingType.Direct) {
            revert NotDirectListing();
        }

        delete listings[_listingId];

        emit ListingRemoved(_listingId, targetListing.tokenOwner);
    }

    /* Direct listing logic */

    function buy(
        uint256 _listingId,
        address _buyFor,
        uint256 _quantityToBuy,
        uint256 _totalPrice
    ) external payable override nonReentrant onlyExistingListing(_listingId) {
        Listing memory targetListing = listings[_listingId];
        address payer = _msgSender();

        // todo: remove this hack to ensure testing this contract only takes hard coded token
        address _currency = _currencyToAccept;

        // Check whether the settled total price and currency to use are correct.
        if (
            _currency != targetListing.currency ||
            _totalPrice != (targetListing.buyoutPricePerToken * _quantityToBuy)
        ) {
            revert InvalidTotalPrice();
        }

        executeSale(
            targetListing,
            payer,
            _buyFor,
            targetListing.currency,
            targetListing.buyoutPricePerToken * _quantityToBuy,
            _quantityToBuy
        );
    }

    function acceptOffer(
        uint256 _listingId,
        address _offeror,
        address _currency,
        uint256 _pricePerToken
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
            _pricePerToken != targetOffer.pricePerToken
        ) {
            revert InvalidPrice();
        }

        if (targetOffer.expirationTimestamp <= block.timestamp) {
            revert OfferExpired();
        }

        delete offers[_listingId][_offeror];

        executeSale(
            targetListing,
            _offeror,
            _offeror,
            targetOffer.currency,
            targetOffer.pricePerToken * targetOffer.quantityWanted,
            targetOffer.quantityWanted
        );
    }

    function executeSale(
        Listing memory _targetListing,
        address _payer,
        address _receiver,
        address _currency,
        uint256 _currencyAmountToTransfer,
        uint256 _listingTokenAmountToTransfer
    ) internal {
        validateDirectListingSale(
            _targetListing,
            _payer,
            _listingTokenAmountToTransfer,
            _currency,
            _currencyAmountToTransfer
        );

        _targetListing.quantity -= _listingTokenAmountToTransfer;
        listings[_targetListing.listingId] = _targetListing;

        payout(
            _payer,
            _targetListing.tokenOwner,
            _currency,
            _currencyAmountToTransfer,
            _targetListing
        );
        transferListingTokens(
            _targetListing.tokenOwner,
            _receiver,
            _listingTokenAmountToTransfer,
            _targetListing
        );

        emit NewSale(
            _targetListing.listingId,
            _targetListing.assetContract,
            _targetListing.tokenOwner,
            _receiver,
            _listingTokenAmountToTransfer,
            _currencyAmountToTransfer
        );
    }

    /* Offer and bids logic */

    /// @dev Lets an account (1) make an offer to a direct listing, or (2) make a bid in an auction.
    function offer(
        uint256 _listingId,
        uint256 _quantityWanted,
        address _currency,
        uint256 _pricePerToken,
        uint256 _expirationTimestamp
    ) external payable override nonReentrant onlyExistingListing(_listingId) {
        Listing memory targetListing = listings[_listingId];

        // Use the custom error in your function
        if (
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
            quantityWanted: _quantityWanted,
            currency: _currency,
            pricePerToken: _pricePerToken,
            expirationTimestamp: _expirationTimestamp
        });

        if (targetListing.listingType == ListingType.Auction) {
            // A bid to an auction must be made in the auction's desired currency.
            if (newOffer.currency != targetListing.currency) {
                revert InvalidCurrency();
            }

            if (newOffer.pricePerToken == 0) {
                revert ZeroAmountBid();
            }

            // A bid must be made for all auction items.
            newOffer.quantityWanted = getSafeQuantity(
                targetListing.tokenType,
                targetListing.quantity
            );

            handleBid(targetListing, newOffer);
        } else if (targetListing.listingType == ListingType.Direct) {
            // Prevent potentially lost/locked native token.
            if (msg.value != 0) {
                revert ValueNotNeeded();
            }

            // Offers to direct listings cannot be made directly in native tokens.
            newOffer.currency = _currency == CurrencyTransferLib.NATIVE_TOKEN
                ? NATIVE_TOKEN_WRAPPER
                : _currency;
            newOffer.quantityWanted = getSafeQuantity(
                targetListing.tokenType,
                _quantityWanted
            );

            handleOffer(targetListing, newOffer);
        }
    }

    function handleOffer(
        Listing memory _targetListing,
        Offer memory _newOffer
    ) internal {
        if (_newOffer.quantityWanted > _targetListing.quantity) {
            revert InsufficientTokensInListing();
        }

        if (_targetListing.quantity <= 0) {
            revert NoTokensInListing();
        }

        validateERC20BalAndAllowance(
            _newOffer.offeror,
            _newOffer.currency,
            _newOffer.pricePerToken * _newOffer.quantityWanted
        );

        offers[_targetListing.listingId][_newOffer.offeror] = _newOffer;

        emit NewOffer(
            _targetListing.listingId,
            _newOffer.offeror,
            _targetListing.listingType,
            _newOffer.quantityWanted,
            _newOffer.pricePerToken * _newOffer.quantityWanted,
            _newOffer.currency
        );
    }

    function handleBid(
        Listing memory _targetListing,
        Offer memory _incomingBid
    ) internal {
        Offer memory currentWinningBid = winningBid[_targetListing.listingId];
        uint256 currentOfferAmount = currentWinningBid.pricePerToken *
            currentWinningBid.quantityWanted;
        uint256 incomingOfferAmount = _incomingBid.pricePerToken *
            _incomingBid.quantityWanted;
        address _nativeTokenWrapper = NATIVE_TOKEN_WRAPPER;

        // Close auction and execute sale if there's a buyout price and incoming offer amount is buyout price.
        if (
            _targetListing.buyoutPricePerToken > 0 &&
            incomingOfferAmount >=
            _targetListing.buyoutPricePerToken * _targetListing.quantity
        ) {
            _closeAuctionForBidder(_targetListing, _incomingBid);
        } else {
            /**
             *      If there's an existng winning bid, incoming bid amount must be bid buffer % greater.
             *      Else, bid amount must be at least as great as reserve price
             */
            if (
                !isNewWinningBid(
                    _targetListing.reservePricePerToken *
                        _targetListing.quantity,
                    currentOfferAmount,
                    incomingOfferAmount
                )
            ) {
                revert NotWinningBid();
            }

            // Update the winning bid and listing's end time before external contract calls.
            winningBid[_targetListing.listingId] = _incomingBid;

            if (_targetListing.endTime - block.timestamp <= timeBuffer) {
                _targetListing.endTime += timeBuffer;
                listings[_targetListing.listingId] = _targetListing;
            }
        }

        // Payout previous highest bid.
        if (currentWinningBid.offeror != address(0) && currentOfferAmount > 0) {
            CurrencyTransferLib.transferCurrencyWithWrapper(
                _targetListing.currency,
                address(this),
                currentWinningBid.offeror,
                currentOfferAmount,
                _nativeTokenWrapper
            );
        }

        // Collect incoming bid
        CurrencyTransferLib.transferCurrencyWithWrapper(
            _targetListing.currency,
            _incomingBid.offeror,
            address(this),
            incomingOfferAmount,
            _nativeTokenWrapper
        );

        emit NewOffer(
            _targetListing.listingId,
            _incomingBid.offeror,
            _targetListing.listingType,
            _incomingBid.quantityWanted,
            _incomingBid.pricePerToken * _incomingBid.quantityWanted,
            _incomingBid.currency
        );
    }

    function isNewWinningBid(
        uint256 _reserveAmount,
        uint256 _currentWinningBidAmount,
        uint256 _incomingBidAmount
    ) internal view returns (bool isValidNewBid) {
        if (_currentWinningBidAmount == 0) {
            isValidNewBid = _incomingBidAmount >= _reserveAmount;
        } else {
            isValidNewBid = (_incomingBidAmount > _currentWinningBidAmount &&
                ((_incomingBidAmount - _currentWinningBidAmount) * MAX_BPS) /
                    _currentWinningBidAmount >=
                bidBufferBps);
        }
    }

    /* Auction sales logic */

    function closeAuction(
        uint256 _listingId,
        address _closeFor
    ) external override nonReentrant onlyExistingListing(_listingId) {
        Listing memory targetListing = listings[_listingId];

        if (targetListing.listingType != ListingType.Auction) {
            revert NotAnAuction();
        }

        Offer memory targetBid = winningBid[_listingId];

        // Cancel auction if (1) auction hasn't started, or (2) auction doesn't have any bids.
        bool toCancel = targetListing.startTime > block.timestamp ||
            targetBid.offeror == address(0);

        if (toCancel) {
            // cancel auction listing owner check
            _cancelAuction(targetListing);
        } else {
            if (targetListing.endTime >= block.timestamp) {
                revert AuctionNotEnded();
            }

            // No `else if` to let auction close in 1 tx when targetListing.tokenOwner == targetBid.offeror.
            if (_closeFor == targetListing.tokenOwner) {
                _closeAuctionForAuctionCreator(targetListing, targetBid);
            }

            if (_closeFor == targetBid.offeror) {
                _closeAuctionForBidder(targetListing, targetBid);
            }
        }
    }

    function _closeAuctionForAuctionCreator(
        Listing memory _targetListing,
        Offer memory _winningBid
    ) internal {
        uint256 payoutAmount = _winningBid.pricePerToken *
            _targetListing.quantity;

        _targetListing.quantity = 0;
        _targetListing.endTime = block.timestamp;
        listings[_targetListing.listingId] = _targetListing;

        _winningBid.pricePerToken = 0;
        winningBid[_targetListing.listingId] = _winningBid;

        payout(
            address(this),
            _targetListing.tokenOwner,
            _targetListing.currency,
            payoutAmount,
            _targetListing
        );

        emit AuctionClosed(
            _targetListing.listingId,
            _msgSender(),
            false,
            _targetListing.tokenOwner,
            _winningBid.offeror
        );
    }

    function _cancelAuction(Listing memory _targetListing) internal {
        if (listings[_targetListing.listingId].tokenOwner != _msgSender()) {
            revert NotListingCreator();
        }

        delete listings[_targetListing.listingId];

        transferListingTokens(
            address(this),
            _targetListing.tokenOwner,
            _targetListing.quantity,
            _targetListing
        );

        emit AuctionClosed(
            _targetListing.listingId,
            _msgSender(),
            true,
            _targetListing.tokenOwner,
            address(0)
        );
    }

    function _closeAuctionForBidder(
        Listing memory _targetListing,
        Offer memory _winningBid
    ) internal {
        uint256 quantityToSend = _winningBid.quantityWanted;

        _targetListing.endTime = block.timestamp;
        _winningBid.quantityWanted = 0;

        winningBid[_targetListing.listingId] = _winningBid;
        listings[_targetListing.listingId] = _targetListing;

        transferListingTokens(
            address(this),
            _winningBid.offeror,
            quantityToSend,
            _targetListing
        );

        emit AuctionClosed(
            _targetListing.listingId,
            _msgSender(),
            false,
            _targetListing.tokenOwner,
            _winningBid.offeror
        );
    }

    /* Color specific market functions */

    function sweepFloor() public {
        /* 1. Loop through all listings
           2. Check if collection address is target, if not break
           3. Check if listing is direct, if not break (check if we want to make auction bids)
           4. --- this might have to be done off chain and realised with the bulkBuy method...
        */
        revert NotImplemented();
    }

    function bulkBuy() public {
        revert NotImplemented();
    }

    function bulkDelist() public {
        revert NotImplemented();
    }

    /* Shared internal functions */

    function payout(
        address _payer,
        address _payee,
        address _currencyToUse,
        uint256 _totalPayoutAmount,
        Listing memory /* _listing */ // todo: uncomment this when royalties working
    ) internal {
        uint256 platformFeeCut = (_totalPayoutAmount * platformFeeBps) /
            MAX_BPS;

        // todo: Consider royalties feature here later!!!

        // uint256 royaltyCut;
        // address royaltyRecipient;

        // // Distribute royalties. See Sushiswap's https://github.com/sushiswap/shoyu/blob/master/contracts/base/BaseExchange.sol#L296
        // try IERC2981(_listing.assetContract).royaltyInfo(_listing.tokenId, _totalPayoutAmount) returns (
        //     address royaltyFeeRecipient,
        //     uint256 royaltyFeeAmount
        // ) {
        //     if (royaltyFeeRecipient != address(0) && royaltyFeeAmount > 0) {
        //         require(royaltyFeeAmount + platformFeeCut <= _totalPayoutAmount, "fees exceed the price");
        //         royaltyRecipient = royaltyFeeRecipient;
        //         royaltyCut = royaltyFeeAmount;
        //     }
        // } catch {}

        // Distribute price to token owner
        address _nativeTokenWrapper = NATIVE_TOKEN_WRAPPER;

        CurrencyTransferLib.transferCurrencyWithWrapper(
            _currencyToUse,
            _payer,
            platformFeeRecipient,
            platformFeeCut,
            _nativeTokenWrapper
        );
        // CurrencyTransferLib.transferCurrencyWithWrapper(
        //     _currencyToUse,
        //     _payer,
        //     royaltyRecipient,
        //     royaltyCut,
        //     _nativeTokenWrapper
        // );
        CurrencyTransferLib.transferCurrencyWithWrapper(
            _currencyToUse,
            _payer,
            _payee,
            _totalPayoutAmount - (platformFeeCut),
            _nativeTokenWrapper
        );
    }

    function validateERC20BalAndAllowance(
        address _addrToCheck,
        address _currency,
        uint256 _currencyAmountToCheckAgainst
    ) internal view {
        if (
            IERC20(_currency).balanceOf(_addrToCheck) <
            _currencyAmountToCheckAgainst ||
            IERC20(_currency).allowance(_addrToCheck, address(this)) <
            _currencyAmountToCheckAgainst
        ) {
            revert InsufficientBalanceOrAllowance();
        }
    }

    // todo: docstring
    function validateOwnershipAndApproval(
        address _tokenOwner,
        address _assetContract,
        uint256 _tokenId,
        uint256 _quantity,
        TokenType _tokenType
    ) internal view {
        address market = address(this);
        bool isValid;

        if (_tokenType == TokenType.ERC1155) {
            isValid =
                IERC1155(_assetContract).balanceOf(_tokenOwner, _tokenId) >=
                _quantity &&
                IERC1155(_assetContract).isApprovedForAll(_tokenOwner, market);
        } else if (_tokenType == TokenType.ERC721) {
            isValid =
                IERC721(_assetContract).ownerOf(_tokenId) == _tokenOwner &&
                (IERC721(_assetContract).getApproved(_tokenId) == market ||
                    IERC721(_assetContract).isApprovedForAll(
                        _tokenOwner,
                        market
                    ));
        }
        if (!isValid) {
            revert TokenNotValidOrApproved();
        }
    }

    function validateDirectListingSale(
        Listing memory _listing,
        address _payer,
        uint256 _quantityToBuy,
        address _currency,
        uint256 settledTotalPrice
    ) internal {
        if (_listing.listingType != ListingType.Direct) {
            revert NotDirectListing();
        }

        // Check whether a valid quantity of listed tokens is being bought.
        if (
            _listing.quantity <= 0 ||
            _quantityToBuy <= 0 ||
            _quantityToBuy > _listing.quantity
        ) {
            revert InvalidTokenAmount();
        }

        // Check if sale is made within the listing window.
        if (
            block.timestamp >= _listing.endTime ||
            block.timestamp <= _listing.startTime
        ) {
            revert NotWithinSaleWindow();
        }

        // Check: buyer owns and has approved sufficient currency for sale.
        // todo: This needs rethinking as Color won't want to take anything other than Eth I think?
        if (_currency == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != settledTotalPrice) {
                revert InvalidMsgValue();
            }
        } else {
            validateERC20BalAndAllowance(_payer, _currency, settledTotalPrice);
        }

        // Check whether token owner owns and has approved `quantityToBuy` amount of listing tokens from the listing.
        validateOwnershipAndApproval(
            _listing.tokenOwner,
            _listing.assetContract,
            _listing.tokenId,
            _quantityToBuy,
            _listing.tokenType
        );
    }

    function transferListingTokens(
        address _from,
        address _to,
        uint256 _quantity,
        Listing memory _listing
    ) internal {
        if (_listing.tokenType == TokenType.ERC1155) {
            IERC1155(_listing.assetContract).safeTransferFrom(
                _from,
                _to,
                _listing.tokenId,
                _quantity,
                ""
            );
        } else if (_listing.tokenType == TokenType.ERC721) {
            IERC721(_listing.assetContract).safeTransferFrom(
                _from,
                _to,
                _listing.tokenId,
                ""
            );
        }
    }

    /* Getters */

    function getSafeQuantity(
        TokenType _tokenType,
        uint256 _quantityToCheck
    ) internal pure returns (uint256 safeQuantity) {
        if (_quantityToCheck == 0) {
            safeQuantity = 0;
        } else {
            safeQuantity = _tokenType == TokenType.ERC721
                ? 1
                : _quantityToCheck;
        }
    }

    function getTokenType(
        address _assetContract
    ) internal view returns (TokenType tokenType) {
        if (
            IERC165(_assetContract).supportsInterface(
                type(IERC1155).interfaceId
            )
        ) {
            tokenType = TokenType.ERC1155;
        } else if (
            IERC165(_assetContract).supportsInterface(type(IERC721).interfaceId)
        ) {
            tokenType = TokenType.ERC721;
        } else {
            revert TokenNotSupported();
        }
    }

    function getPlatformFeeInfo() external view returns (address, uint16) {
        return (platformFeeRecipient, uint16(platformFeeBps));
    }

    /* Setters */
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

    function setAuctionBuffers(
        uint256 _timeBuffer,
        uint256 _bidBufferBps
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Use the custom error in your function
        if (_bidBufferBps >= MAX_BPS) {
            revert InvalidBPS(_bidBufferBps, MAX_BPS);
        }

        timeBuffer = uint64(_timeBuffer);
        bidBufferBps = uint64(_bidBufferBps);

        emit AuctionBuffersUpdated(_timeBuffer, _bidBufferBps);
    }

    /* Misc */

    /// @dev Overrides the default _msgSender() function to use the ERC2771Context implementation.
    function _msgSender()
        internal
        view
        override(Context, ERC2771Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /// @dev Overrides the default _msgData() function to use the ERC2771Context implementation.
    function _msgData()
        internal
        view
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    /// @dev Overrides the default _contextContract() function to use the ERC2771Context implementation.
    function _contextSuffixLength()
        internal
        view
        override(Context, ERC2771Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }
}
