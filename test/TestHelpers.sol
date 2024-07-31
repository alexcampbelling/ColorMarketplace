// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseTest } from "./utils/BaseTest.sol";
// import { console } from "forge-std/Test.sol";
import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";

import { console } from "forge-std/Test.sol";

contract TestHelpers is BaseTest {

    ColorMarketplace public color;

    // Common variable names
    address public deployer;
    address public seller;
    address public buyer;
    address public trustedForwarder;
    address public nativeTokenWrapper;
    address public defaultAdmin;
    string public contractURI;
    address public platformFeeRecipient;
    uint256 public platformFeeBps;
    address[] public erc20Whitelist;
    address LicenseTokenAddress;

    // Known constants
    address NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public override {
        super.setUp();
        deployer = getActor(0);
        seller = getActor(1);
        buyer = getActor(2);

        // Trusted forwarder address. Replace this with your trusted forwarder address.
        trustedForwarder = 0x0000000000000000000000000000000000000000;

        // WETH address on Sepolia.
        nativeTokenWrapper = address(weth);

        // Default admin address. Replace this with your default admin address.
        defaultAdmin = deployer;

        // ContractURI setting
        contractURI = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

        // Platform fee recipient address. Replace this with your platform fee recipient address.
        platformFeeRecipient = deployer;

        // Platform fee in basis points. Replace this with your platform fee.
        platformFeeBps = 100;

        erc20Whitelist = new address[](1);
        erc20Whitelist[0] = address(erc20);

        address licenseTokenAddress = 0x1333c78A821c9a576209B01a16dDCEF881cAb6f2;

        color = new ColorMarketplace(
            nativeTokenWrapper,
            trustedForwarder, 
            defaultAdmin, 
            contractURI, 
            platformFeeRecipient, 
            platformFeeBps,
            erc20Whitelist,
            licenseTokenAddress
        );
    }

    function getBasicListing(
        uint256 _tokenId,
        address _seller,
        address _color,
        address _assetContract,
        address _currency,
        IColorMarketplace.ListingType _listingType,
        uint256 _reservePricePerToken,
        uint256 _buyoutPricePerToken,
        bool isERC1155
    ) public returns (IColorMarketplace.ListingParameters memory) {
        // // Sample listing parameters.
        // address assetContract = _assetContract;
        // uint256 tokenId = _tokenId;
        // uint256 startTime = 100;
        // uint256 secondsUntilEndTime = 200;
        // uint256 quantityToList = 1;
        // address currency = _currency;

        // Mint token for seller
        if (isERC1155) {
            _setupERC1155BalanceForSeller(_seller, _tokenId, 1);
        } else {
            _setupERC721BalanceForSeller(_seller, 1);
        }

        // Approve Marketplace to transfer token.
        vm.prank(_seller);
        if (isERC1155) {
            erc1155.setApprovalForAll(address(_color), true);
        } else {
            erc721.setApprovalForAll(address(_color), true);
        }

        // List token
        IColorMarketplace.ListingParameters memory listingParams = IColorMarketplace.ListingParameters(
            _assetContract,
            _tokenId,
            100,
            200,
            1, // todo: add abilitity to change via arguments
            _currency,
            _reservePricePerToken,
            _buyoutPricePerToken,
            _listingType
        );
        return listingParams;
    }

    function getBasicDirectListing(
        uint256 _tokenId,
        address _seller,
        address _color,
        address _assetContract,
        address _currency,
        bool isERC1155
    ) public returns (IColorMarketplace.ListingParameters memory) {
        return getBasicListing(
            _tokenId,
            _seller,
            _color,
            _assetContract,
            _currency,
            IColorMarketplace.ListingType.Direct,
            0, // reservePricePerToken is not needed for direct listing
            1 ether,
            isERC1155
        );
    }

    function getBasic721AuctionListing() public returns (IColorMarketplace.ListingParameters memory) {
        return getBasicListing(
            0,
            seller,
            address(color),
            address(erc721),
            address(erc20),
            IColorMarketplace.ListingType.Auction,
            1 ether,
            2 ether,
            false // isERC1155
        );
    }

    function getBasic1155AuctionListing(uint256 _tokenId, address _seller, address _color, address _assetContract, address _currency) public returns (IColorMarketplace.ListingParameters memory) {
        return getBasicListing(
            _tokenId,
            _seller,
            _color,
            _assetContract,
            _currency,
            IColorMarketplace.ListingType.Auction,
            1 ether,
            2 ether,
            true // isERC1155
        );
    }
}
