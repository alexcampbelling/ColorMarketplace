// Tests for checking set up of the marketplace is clean and correct

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";

contract SetupTests is TestHelpers {

    function test_add_erc20_whitelist_success() public {
        // Make spoof token to be accepted
        MockERC20 mockToken = new MockERC20();

        // Increment totalSupply
        mockToken.mint(address(color), 1000000000000000000000000000);

        // Add the ERC20 to the whitelist
        vm.prank(deployer);
        color.erc20WhiteListAdd(address(mockToken));

        // Check that the ERC20 is in the whitelist
        bool isWhitelisted = color.isErc20Whitelisted(address(mockToken));
        vm.assertEq(isWhitelisted, true);
    }

    function test_contractDeployment_success() public {vm.skip(true);}
    function test_setAdmin_success() public {vm.skip(true);}
    function test_setPlatformFee_success() public {vm.skip(true);}
    function test_setAdmin_invalidAddress_failure() public {vm.skip(true);}
    function test_setPlatformFee_invalidValue_failure() public {vm.skip(true);}
}
