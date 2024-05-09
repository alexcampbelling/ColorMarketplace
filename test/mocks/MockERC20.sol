// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockERC20 is ERC20 {
    bool internal taxActive;

    constructor() ERC20("Mock Coin", "MOCK"){}

    function mint(address to, uint256 amount) public {
      _mint(to, amount);
    }
}
