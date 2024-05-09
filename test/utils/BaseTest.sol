// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import { Test, console } from "forge-std/Test.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockERC721 } from "../mocks/MockERC721.sol";

abstract contract BaseTest is Test {

    MockERC20 public erc20;
    MockERC721 public erc721;

    function setUp() public virtual {
        // Create mock contracts
        erc20 = new MockERC20();
        erc721 = new MockERC721();
        // erc1155 = new MockERC1155();
    }

    function getActor(uint160 _index) public pure returns (address) {
        return address(uint160(0x50000 + _index));
    }
}