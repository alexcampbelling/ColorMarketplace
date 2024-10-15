// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseTest } from "./utils/BaseTest.sol";
import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { console } from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract TestHelpers is BaseTest {
    
    ColorMarketplace public colorMarketplace;
    address public proxy;

    // Common variable names
    address public deployer;
    address public seller;
    address public buyer;
    address public trustedForwarder;
    address public nativeTokenWrapper;
    address public defaultAdmin;
    address public platformFeeRecipient;
    uint256 public platformFeeBps;
    address[] public erc20Whitelist;
    address public licenseTokenAddress;

    // Known constants
    address NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public override {
        super.setUp();
        deployer = getActor(0);
        seller = getActor(1);
        buyer = getActor(2);

        // Trusted forwarder address. Replace this with your trusted forwarder address.
        trustedForwarder = address(0);

        // WETH address on Sepolia.
        nativeTokenWrapper = address(weth);

        // Default admin address. Replace this with your default admin address.
        defaultAdmin = deployer;

        // Platform fee recipient address. Replace this with your platform fee recipient address.
        platformFeeRecipient = deployer;

        // Platform fee in basis points. Replace this with your platform fee.
        platformFeeBps = 100;

        erc20Whitelist = new address[](1);
        erc20Whitelist[0] = address(erc20);

        licenseTokenAddress = address(0x1333c78A821c9a576209B01a16dDCEF881cAb6f2);

        // Deploy the upgradeable contract
        proxy = Upgrades.deployUUPSProxy(
            "ColorMarketplace.sol",
            abi.encodeCall(
                ColorMarketplace.initialize,
                (
                    address(0), // _nativeTokenWrapper
                    address(this), // _defaultAdmin
                    address(this), // _platformFeeRecipient
                    100, // _platformFeeBps
                    new address[](0), // _erc20Whitelist
                    address(0) // _licenseTokenAddress
                )
            )
        );

        // Cast the proxy address to ColorMarketplace
        colorMarketplace = ColorMarketplace(payable(proxy));
    }

    function getBasicListing(
        uint256 _tokenId,
        address _seller,
        address _color,
        address _assetContract,
        address _currency,
        uint256 _buyoutPrice
    ) public returns (IColorMarketplace.ListingParameters memory) {
        // Mint token for seller
        _setupERC721BalanceForSeller(_seller, 1);
        
        // Approve Marketplace to transfer token.
        vm.prank(_seller);
        erc721.setApprovalForAll(address(_color), true);

        // List token
        IColorMarketplace.ListingParameters memory listingParams = IColorMarketplace.ListingParameters(
            _assetContract,
            _tokenId,
            100,
            200,
            _currency,
            _buyoutPrice
        );
        return listingParams;
    }

    function getBasicListing(
        uint256 _tokenId,
        address _seller,
        address _color,
        address _assetContract,
        address _currency
    ) public returns (IColorMarketplace.ListingParameters memory) {
        return getBasicListing(
            _tokenId,
            _seller,
            _color,
            _assetContract,
            _currency,
            1 ether
        );
    }
}