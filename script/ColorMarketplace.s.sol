// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/ColorMarketplace.sol";

contract ColorMarketPlaceDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Trusted forwarder address. Replace this with your trusted forwarder address.
        address trustedForwarder = 0x0000000000000000000000000000000000000000;

        // WETH address on Sepolia.
        address nativeTokenWrapper = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

        // Default admin address. Replace this with your default admin address.
        address defaultAdmin = vm.envAddress("CONTRACT_ADMIN_ADDRESS");

        // ContractURI setting
        string memory contractURI = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

        // Platform fee recipient address. Replace this with your platform fee recipient address.
        address platformFeeRecipient = vm.envAddress("CONTRACT_ADMIN_ADDRESS");

        // Platform fee in basis points. Replace this with your platform fee.
        uint256 platformFeeBps = 100; // todo: set this correctly, 100 means 1% of transfers is taxed

        // Just add WTC 0x16EFdA168bDe70E05CA6D349A690749d622F95e0
        // Can mint via 0x9a2c5733758c9e7e29ae632eeba88f077dbcfde2 (mock token faucet which mints)
        address[] memory erc20Whitelist = new address[](1);
        erc20Whitelist[0] = 0x16EFdA168bDe70E05CA6D349A690749d622F95e0;

        // Un-used as of current - would theoretically help with not listing non transferable tokens
        // However there are failsafes in place to prevent this (transfers on those tokens will fail)
        // This is from the Story website
        address LicenseTokenAddress = 0x1333c78A821c9a576209B01a16dDCEF881cAb6f2;

        new ColorMarketplace(
            trustedForwarder, 
            nativeTokenWrapper, 
            defaultAdmin, 
            contractURI, 
            platformFeeRecipient, 
            platformFeeBps,
            erc20Whitelist,
            LicenseTokenAddress
        );

        vm.stopBroadcast();
    }
}