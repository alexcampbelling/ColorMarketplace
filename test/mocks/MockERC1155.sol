// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC1155 is ERC1155, Ownable {
    uint256 public nextTokenIdToMint;
    mapping(uint256 => string) private _tokenURIs;

    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function mintNew(address to, uint256 amount, bytes memory data) public onlyOwner returns (uint256) {
        uint256 newId = nextTokenIdToMint++;
        _mint(to, newId, amount, data);
        return newId;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI) public onlyOwner {
        _tokenURIs[tokenId] = tokenURI;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
        string memory base = super.uri(tokenId);

        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }

        return base;
    }

    function burn(address account, uint256 id, uint256 value) public virtual {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved");

        _burn(account, id, value);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public virtual {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved");

        _burnBatch(account, ids, values);
    }
}
