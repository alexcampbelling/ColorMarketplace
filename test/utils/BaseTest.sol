// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test, console } from "forge-std/Test.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockERC721 } from "../mocks/MockERC721.sol";
import { WETH9 } from "../mocks/WETH9.sol";

abstract contract BaseTest is Test {

    MockERC20 public erc20;
    MockERC721 public erc721;
    WETH9 public weth;

    function setUp() public virtual {
        // Create mock contracts
        erc20 = new MockERC20();
        erc721 = new MockERC721();
        weth = new WETH9();
    }

    function getActor(uint160 _index) public pure returns (address) {
        return address(uint160(0x50000 + _index));
    }

    function _setupERC721BalanceForSeller(address _seller, uint256 _numOfTokens) public {
        erc721.mint(_seller, _numOfTokens);
    }
}
