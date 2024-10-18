// Tests for role specific functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ColorMarketplace } from "../src/ColorMarketplace.sol";
import { IColorMarketplace } from "../src/IColorMarketplace.sol";
import { TestHelpers } from "./TestHelpers.sol";

contract RolesTests is TestHelpers {
    function test_onlyAdmin() public {vm.skip(true);}
    function test_onlyLister() public {vm.skip(true);}
}
