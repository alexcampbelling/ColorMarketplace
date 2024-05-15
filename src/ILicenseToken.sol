// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

interface ILicenseToken {

    struct LicenseTokenMetadata {
        address licensorIpId;
        address licenseTemplate;
        uint256 licenseTermsId;
        bool transferable;
    }

    /// @notice Retrieves the metadata associated with a License Token.
    /// @param tokenId The ID of the License Token.
    /// @return A `LicenseTokenMetadata` struct containing the metadata of the specified License Token.
    function getLicenseTokenMetadata(uint256 tokenId) external view returns (LicenseTokenMetadata memory);

}