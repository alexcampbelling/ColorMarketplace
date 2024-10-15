// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/ColorMarketplace.sol";
import "../src/ColorMarketplaceProxy.sol";
import "../src/ColorMarketplaceProxyAdmin.sol";

contract ColorMarketPlaceDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        ColorMarketplace implementation = new ColorMarketplace();

        // Deploy ProxyAdmin
        ColorMarketplaceProxyAdmin proxyAdmin = new ColorMarketplaceProxyAdmin(deployer);

        // WETH address on Sepolia.
        address nativeTokenWrapper = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

        // Platform fee recipient address
        address platformFeeRecipient = deployer;

        // Platform fee in basis points (100 = 1%)
        uint256 platformFeeBps = 100;

        // Just add WTC 0x16EFdA168bDe70E05CA6D349A690749d622F95e0
        // Can mint via 0x9a2c5733758c9e7e29ae632eeba88f077dbcfde2 (mock token faucet which mints)
        address[] memory erc20Whitelist = new address[](1);
        erc20Whitelist[0] = 0x16EFdA168bDe70E05CA6D349A690749d622F95e0;

        // Un-used as of current - would theoretically help with not listing non transferable tokens
        // However there are failsafes in place to prevent this (transfers on those tokens should fail)
        address licenseTokenAddress = 0x1333c78A821c9a576209B01a16dDCEF881cAb6f2;

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            ColorMarketplace.initialize.selector,
            nativeTokenWrapper,
            deployer, // _defaultAdmin
            platformFeeRecipient,
            platformFeeBps,
            erc20Whitelist,
            licenseTokenAddress
        );

        // Deploy Proxy
        ColorMarketplaceProxy proxy = new ColorMarketplaceProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );

        // todo alex: test this on testnet!
        console.log("ColorMarketplace Proxy deployed at:", address(proxy));
        console.log("ColorMarketplace Implementation deployed at:", address(implementation));
        console.log("ColorMarketplace ProxyAdmin deployed at:", address(proxyAdmin));

        vm.stopBroadcast();
    }
}