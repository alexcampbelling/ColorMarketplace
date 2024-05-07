// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ColorNFT is ERC721URIStorage {
    uint256 private _tokenCounter;

    event NFTMinted(uint256 indexed _tokenCounter);

    constructor() ERC721("ColorNFT", "CNFT-T") {}

    function mint(string memory tokenURI) public returns (uint256) {
        _tokenCounter = _tokenCounter + 1;

        uint256 newItemId = _tokenCounter;
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        emit NFTMinted(newItemId);

        return newItemId;
    }
}
