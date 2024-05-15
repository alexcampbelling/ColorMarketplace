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
    
    function getBasicDirectListing(uint256 _tokenId, address _seller, address _color) public returns (IColorMarketplace.ListingParameters memory){
        // Sample listing parameters.
        address assetContract = address(erc721);
        uint256 tokenId = _tokenId;
        uint256 startTime = 100;
        uint256 secondsUntilEndTime = 200;
        uint256 quantityToList = 1;
        address currency = address(erc20);
        uint256 reservePricePerToken; // not an auction, does not need to be set
        uint256 buyoutPricePerToken = 1 ether;
        IColorMarketplace.ListingType listingType = IColorMarketplace.ListingType.Direct;

        // Mint token for seller
        _setupERC721BalanceForSeller(_seller, 1);

        // Approve Marketplace to transfer token.
        vm.prank(_seller);
        erc721.setApprovalForAll(address(_color), true);

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
        return listingParams;
    }

    function getBasicAuctionListing() public returns (IColorMarketplace.ListingParameters memory){
        // Sample listing parameters.
        address assetContract = address(erc721);
        uint256 tokenId = 0;
        uint256 startTime = 100;
        uint256 secondsUntilEndTime = 200;
        uint256 quantityToList = 1;
        address currency = address(erc20);
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
        return listingParams;
    }
}
