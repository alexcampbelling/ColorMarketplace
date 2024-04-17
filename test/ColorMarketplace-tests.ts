import hre from "hardhat";
import { expect } from "chai";
import { ethers } from "ethers";

// For interacting with Color contract
enum TokenType {
  ERC721 = 0,
  ERC1155 = 1
}

describe("Color Marketplace", function () {
  let ColorMarket: ethers.Contract;
  let ColorNFT: ethers.Contract;

  beforeEach(async function () {
    try {
      // Deploy market to hre
      ColorMarket = await hre.ethers.deployContract("ColorMarketplace");
      // Deploy the NFT contract
      ColorNFT = await hre.ethers.deployContract("ColorNFT");
    } catch (error) {
      console.error("Failed to initialize contracts:", error);
    }
  });

  it("Check contract successfully deployed to hardhat runtime environment", async function () {
    // Check if contract was deployed
    const marketAddress = ColorMarket.address;
    
    console.log(`Debug | Market address: ${marketAddress}`)

    expect(marketAddress).to.be.ok;
    expect(marketAddress).match(/^0x[a-fA-F0-9]{40}$/);

    // Check if interacting with the contract works
    const marketName = await ColorMarket.NAME();

    console.log(`Debug | Market name: ${marketName}`)

    expect(marketName).to.equal("Color Marketplace");
  });

  it("Mint 721 NFT and list on market", async function () {

    ColorMarket.on("ListingCreated", () => {
      console.log(`Listing created: `);
    });

    // Get the owner account
    const [owner] = await hre.ethers.getSigners();

    console.log(`Debug | owner address: ${owner.address}`)

    // Connect the ColorMarket contract with the owner account
    const ColorMarketWithSigner = ColorMarket.connect(owner);

    // Mint random named 721 NFT
    const transaction =  await ColorNFT.mintNFT(
      `TestNFT-${Math.floor(Math.random() * 10000)}`
    );
    const receipt = await transaction.wait();

    // Take the tokenId from the mint event emission logs
    const tokenId = receipt.events.find((event: { event: string; }) => event.event === 'NFTMinted')?.args;
    console.log(`DEBUG | Minted NFT with Token ID: ${tokenId}`);

    // List NFT on market
    const price = ethers.utils.parseEther("1"); // Set the price to 1 ETH

    // Call the createListing function
    // todo: alex: this is not working
    await ColorMarketWithSigner.createListing(TokenType.ERC721, ColorNFT.address, tokenId, price, 1);

    // Read contract directly to see what has been listed
    const listing = await ColorMarket.LISTINGS(tokenId);
    console.log(`Listing details: Listing ID - ${listing.listingId}, Token ID - ${listing.tokenId}, Price - ${listing.price}, Seller - ${listing.seller}`);
  })

  // Rest of the test cases...
});