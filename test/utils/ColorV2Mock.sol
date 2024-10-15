// ColorV2Mock.sol
pragma solidity ^0.8.25;

import "../../src/ColorMarketplace.sol";

/// @custom:storage-location erc7201:colormarketplace.storage
/// @custom:oz-upgrades-from ColorMarketplace
contract ColorMarketplaceV2 is ColorMarketplace {
    struct ColorMarketplaceV2Storage {
        bool newFeature;
    }

    bytes32 private constant STORAGE_LOCATION_V2 = keccak256("colormarketplace.v2.storage");

    function _getStorageV2() private pure returns (ColorMarketplaceV2Storage storage $) {
        bytes32 position = STORAGE_LOCATION_V2;
        assembly {
            $.slot := position
        }
    }

    function initialize() reinitializer(2) public {
        ColorMarketplaceStorage storage $ = _getStorage();
        $.chainVersion = 2;

        ColorMarketplaceV2Storage storage $v2 = _getStorageV2();
        $v2.newFeature = false;
    }

    function setNewFeature(bool _value) public onlyRole(DEFAULT_ADMIN_ROLE) {
        ColorMarketplaceV2Storage storage $v2 = _getStorageV2();
        $v2.newFeature = _value;
    }

    function getNewFeature() public view returns (bool) {
        ColorMarketplaceV2Storage storage $v2 = _getStorageV2();
        return $v2.newFeature;
    }
}