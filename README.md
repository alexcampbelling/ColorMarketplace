# Color Marketplace

## Description

Color Marketplace is a decentralized NFT marketplace built on the Story Layer 2 network. It's designed to integrate seamlessly with the Story Protocol, providing a platform for trading IP assets while respecting and enforcing the protocol's licensing and royalty mechanisms.

This is a completely on-chain solution, however we may plan to go partially off-chain in the future. 😊

Visit us at [colormp.com](https://www.colormp.com/) to explore our marketplace and start trading!

For more information about the underlying protocol powering our marketplace, check out the [Story Protocol website](https://www.story.foundation/).

## Table of Contents

- [Features](#features)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Deployment](#deployment)
  - [Usage](#usage)
- [Testing](#testing)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Features

1. **Direct Listing**: Create listings for ERC721 tokens with customizable parameters.

2. **Batch Listing**: Create multiple listings in a single transaction.

3. **Listing Management**: Update or cancel existing listings.

4. **Direct Buy**: Purchase listed items at the buyout price.

5. **Bulk Buying**: Purchase multiple listings in one transaction.

6. **Offer System**: Make offers on listings, including below buyout price.

7. **Offer Management**: Cancel or accept offers on listings.

8. **Multi-Currency**: Support for native cryptocurrency and whitelisted ERC20 tokens.

9. **Platform Fee**: Customizable fee system for marketplace revenue.

10. **Whitelist Management**: Add or remove ERC20 tokens from the accepted list.

11. **Meta-Transactions**: Support for ERC2771 standard.

12. **Access Control**: Role-based permissions for admin functions.

13. **Reentrancy Protection**: Safeguards against reentrancy attacks.

14. **Story Protocol Integration**: Prepared for future licensing and royalty management.

15. **ERC721 Receiver**: Capability to receive ERC721 tokens.

16. **Flexible Pricing**: Different prices and currencies for each listing.

17. **Timed Listings**: Listings with customizable start and end times.

18. **Offer Expiration**: Offers include an expiration timestamp.

19. **Bulk Operations**: Support for batch actions on listings and offers.

20. **Event Emission**: Detailed events for major actions.

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

### Deployment

1. Edit the deployment script at `script/ColorMarketplace.s.sol` to set your parameters.

2. Copy the example environment file and fill in your variables:

   ```bash
   cp .env.example .env
   ```

3. Deploy to Sepolia testnet:
   ```bash
   forge script ColorMarketPlaceDeploy --rpc-url $SEPOLIA_RPC_URL --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast
   ```

### Usage

#### Listing and buying life cycle

- User A creates a listing:

```
A calls createListing(ListingParameters{
    assetContract: NFT_CONTRACT_ADDRESS,
    tokenId: 1,
    startTime: CURRENT_TIME,
    secondsUntilEndTime: 7 DAYS,
    currency: ERC20_TOKEN_ADDRESS,
    buyoutPrice: 1 ETHER,
    royaltyInfo: RoyaltyInfo{receiver: ROYALTY_RECEIVER, percentage: 250} // 2.5%
  })
```

- User B buys the listing:

```
B calls buy(listingId: 0, buyFor: B's_ADDRESS)
```

#### Bidding on listings

- User C makes an offer:

```
  C calls offer(listingId: 0, price: 0.8 ETHER, expirationTimestamp: CURRENT_TIME + 1 DAY)
```

- User A (listing owner) accepts the offer:

```
  A calls acceptOffer(listingId: 0, offeror: C's_ADDRESS)
```

#### Admin commands

- Update platform fee:

```
  Admin calls setPlatformFeeInfo(newFeeRecipient: FEE_RECIPIENT_ADDRESS, newFeeBps: 250) // 2.5%
```

- Add ERC20 token to whitelist:

```
  Admin calls erc20WhiteListAdd(tokenAddress: NEW_ERC20_TOKEN_ADDRESS)
```

- Remove ERC20 token from whitelist:

```
Admin calls erc20WhiteListRemove(tokenAddress: ERC20_TOKEN_ADDRESS)
```

- Transfer admin ownership:

```
Admin calls transferAdminOwnership(newAdmin: NEW_ADMIN_ADDRESS)
```

- Cancel a listing:

```
Admin calls adminCancelListing(listingId: LISTING_ID)
```

- Cancel an offer:

```
Admin calls adminCancelOffer(listingId: LISTING_ID, offeror: OFFEROR_ADDRESS)
```

#### How royalties work

Royalties are set when creating a listing and cannot be changed after listing creation. They are specified as a percentage (in basis points) and a receiver address.

- When a sale occurs, the royalty is calculated as:

```
royaltyAmount = salePrice * royaltyPercentage / 10000
```

- The royalty is sent to the specified receiver address during the sale transaction.
- Royalties are optional. If no royalty is desired, set the receiver to the zero address and percentage to 0.

## Testing

To run the test suite:

```bash
forge test
```

For more detailed output, including traces for failing tests, use:

```bash
forge test -vvvv
```

Optionally mark the test you want to focus on with:

```bash
forge test --match-test  testFunctionName
```

And for gas reports:

```bash
forge test --gas-report
```

## Security

While we strive to ensure the security of our smart contracts, please note:

1. This project is currently unaudited. We plan to conduct a professional audit in the near future. These will be made available in this repo.

2. The contract uses OpenZeppelin's security features including ReentrancyGuard and AccessControl.

3. This is experimental software and users interact with it at their own risk.

We advise users to exercise caution and not to commit funds they cannot afford to lose.

## Contributing

We are still in the early version of this marketplace, and are likely to move to an off-chain solution that follow closer to modern marketplace structures. So this project may become stale quickly. Contribute at your own time risk!

## License

This project is licensed under the MIT License.

## Contact

For any questions, suggestions, or discussions about the Color Marketplace, please join our Discord community:

[Join our Discord](https://discord.gg/FqaKejRXVM)

We look forward to connecting with you and building the future of NFT trading together!

## Todo:

- Add minimum offer amounts on listings. Or a number to deny the ability to offer?
