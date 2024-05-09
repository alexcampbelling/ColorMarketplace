// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/ColorMarketplace.sol";
import { console } from "forge-std/Test.sol";

contract ColorMarketPlaceDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Trusted forwarder address. Replace this with your trusted forwarder address.
        address trustedForwarder = 0x0000000000000000000000000000000000000000;

        // WETH address on Sepolia.
        address nativeTokenWrapper = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

        // todo: update constructor with full init arguments (fee receivers, etc.)
        new ColorMarketplace(trustedForwarder, nativeTokenWrapper);

        vm.stopBroadcast();
    }
}