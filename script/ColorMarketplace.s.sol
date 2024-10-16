// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/ColorMarketplace.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract ColorMarketPlaceDeploy is Script {

    ColorMarketplace public color;
    address public proxy;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

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

        // Deploy the upgradeable contract
        proxy = Upgrades.deployUUPSProxy(
            "ColorMarketplace.sol",
            abi.encodeCall(
                ColorMarketplace.initialize,
                (
                    nativeTokenWrapper, // _nativeTokenWrapper
                    deployer, // _defaultAdmin
                    platformFeeRecipient, // _platformFeeRecipient
                    platformFeeBps, // _platformFeeBps
                    erc20Whitelist // _erc20Whitelist
                )
            )
        );

        // Cast the proxy address to ColorMarketplace
        color = ColorMarketplace(payable(proxy));

        console.log("ColorMarketplace Proxy deployed at:", address(proxy));
        console.log("ColorMarketplace Implementation deployed at:", address(color));

        vm.stopBroadcast();
    }
}