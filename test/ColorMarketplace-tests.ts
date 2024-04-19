import hre from "hardhat";
import { expect } from "chai";
import { ethers } from "ethers";

// For interacting with Color contract
enum TokenType {
  ERC721 = 0,
  ERC1155 = 1
}

describe("Color Marketplace Testing", function () {
  let ColorMarket: ethers.Contract;
  let ColorNFT: ethers.Contract;

  before(async function () {
    try {
      // Deploy market to hre
      ColorMarket = await hre.ethers.deployContract("ColorMarketplace");
      // Deploy the NFT contract
      ColorNFT = await hre.ethers.deployContract("ColorNFT");
    } catch (error) {
      console.error("Failed to initialize contracts:", error);
    }
  });

  describe("Deployment and on chain checks", async function () {
    it("Check contract successfully deployed to hardhat runtime environment", async function () {
      // Check if contract was deployed
      const marketAddress = ColorMarket.address;
  
      expect(marketAddress).to.be.ok;
      expect(marketAddress).match(/^0x[a-fA-F0-9]{40}$/);
  
      // Check if interacting with the contract works
      const marketName = await ColorMarket.NAME();
  
      expect(marketName).to.equal("Color Marketplace");
    });

    it("Market deployed to target address");

    it("Basic variable reads on the market can be done"); // Get the name, version, listings, etc.

    it("Check all feature public functions are reachable");

    it("Check all internal functions are not reachable");

    it("todo: add proxy upgrade functionality checks");
  })

  describe("Basic feature checks", async function() {
    it("Mint 721 NFT and list on market", async function () {
      // Get the owner and another account
      const [account1] = await hre.ethers.getSigners();
  
      // Connect to the NFT contract and mint an NFT
      const mintNFTReceipt = await connectAndMintNFT(account1, ColorNFT, ColorMarket);
  
      try {
        // Find the 'NFTMinted' event
        const mintedEvent = findEventByName(mintNFTReceipt, 'NFTMinted')!;
        const tokenId = mintedEvent.args![0];
  
        // Connect the ColorMarket contract with account1
        const ColorMarketWithSigner = ColorMarket.connect(account1);
      
        // Call the createListing function
        const price = ethers.utils.parseEther("1"); // Set the price to 1 ETH
        const createListingReceipt = await (await ColorMarketWithSigner.createListing(TokenType.ERC721, ColorNFT.address, tokenId, price, 1)).wait();
      
        // Find the 'ListingCreated' event
        const listingCreatedEvent = findEventByName(createListingReceipt, 'ListingCreated')!;
      
        // Parse the event data
        const parsedEventData = ColorMarket.interface.parseLog(listingCreatedEvent);
        const eventFragment = ColorMarket.interface.getEvent('ListingCreated');
        const eventData = parseEventArguments(parsedEventData, eventFragment);
      
        // The key of the listing we want to retrieve
        const listingKey = 0;
      
        // Call the listings function
        const listing = await ColorMarket.listings(listingKey);
      
        const expectedValues = {
          tokenType: TokenType.ERC721,
          contractAddress: ColorNFT.address,
          seller: account1.address,
          listingId: "0",
          tokenId: "1",
          price: price.toString(),
          amount: "1",
        };
        const expectedValuesString = JSON.stringify(expectedValues);
      
        // Parse eventData and listing
        const eventDataValues = parseEventData(eventData);
        const listingValues = parseListingData(listing);
      
        // Convert argDataValues and listingValues to JSON strings
        const eventDataValuesString = JSON.stringify(eventDataValues);
        const listingValuesString = JSON.stringify({ ...listingValues, availableAmount: undefined });
      
        // Check the values of argDataValues and listingValues
        expect(eventDataValuesString).to.equal(expectedValuesString);
        expect(listingValuesString).to.equal(expectedValuesString);
      } catch (error) {
        console.error(`Error occurred in "Mint 721 NFT and list on market":`, error);
        throw error;
      }
  
    })
  
    it("Mint 1155 NFT and list on market");
  
    it("Batch listings correctly list");

    it("Remove listing");

    it("Purchase listing");
  
    it("Only can buy with $STORY token");
    
    // todo: add auction functionality and tests
  })

  describe("Story protocol specific checks", async function() {
    it("todo: Add checks for Story protocol specific features");
  })

  describe("Custom error checks", function() {
    it("Should throw NotTokenOwner error when caller is not the token owner");
  
    it("Should throw InvalidArrayLength error when array length is invalid");
  
    it("Should throw InsufficientPayment error when payment sent is less than required");
  
    it("Should throw SellerDoesNotOwnToken error when seller does not own the token");
  
    it("Should throw ContractNotApproved error when contract is not approved");
  
    it("Should throw SellerDoesNotHaveEnoughTokens error when seller does not have enough tokens");
  
    it("Should throw InvalidTokenType error when token type is invalid");
  
    it("Should throw CannotBuyOwnListing error when buyer is also the seller");
  
    it("Should throw ListingNotAvailable error when listing is not available");
  
    it("Should throw NotEnoughTokensAvailable error when there are not enough tokens available");
  
    it("Should throw PriceMustBeGreaterThanZero error when price is zero or less");
  
    it("Should throw AmountMustBeGreaterThanZero error when amount is zero or less");
  
    it("Should throw ListingDoesNotExist error when listing does not exist");
  
    it("Should throw NotListingOwner error when caller is not the listing owner");
  
    it("Should throw CannotBuyPartialERC721 error when trying to buy partial ERC721 token");
  });

  describe("Common attack vector checks", async function() {

    // A reentrancy attack is when an external contract hijacks the control flow, and re-enters the calling contract, leading to state changes that the calling contract did not intend.
    // https://www.quicknode.com/guides/ethereum-development/smart-contracts/a-broad-overview-of-reentrancy-attacks-in-solidity-contracts
    it("Reentry attack check"); 
  
    // This mainly checks that we indeed use the safemath library
    it("Arithmetic Overflow and Underflow");

    // If we add owner only functions, we need to check that the owner is the only one who can call them
    it("Access Control checks");
  })
});

function findEventByName(receipt: ethers.ContractReceipt, eventName: string): ethers.Event | undefined {
  if (receipt && receipt.events) {
    return receipt.events.find(event => event.event === eventName);
  }
  return undefined;
}

// todo: abstract to take type of nft, 721 vs 1155
async function connectAndMintNFT(account: ethers.Signer, nftContract: ethers.Contract, market?: ethers.Contract): Promise<ethers.ContractReceipt> {
  // Generate a random name for the NFT
  const nftName = `TestNFT-${Math.floor(Math.random() * 10000)}`;

  // Connect the NFT contract with the account
  const nftContractWithSigner = nftContract.connect(account);

  // Mint the NFT
  const mintTx = await nftContractWithSigner.mint(nftName);

  // If market exists, set approval for all
  if (market) {
    const approvalTx = await nftContractWithSigner.setApprovalForAll(market.address, true);
    await approvalTx.wait();
  }

  return await mintTx.wait();
}

function parseEventData(eventData: { [key: string]: { value: any } }): { [key: string]: string | number } {
  const eventDataValues: { [key: string]: string | number } = {};
  for (const [key, value] of Object.entries(eventData)) {
    eventDataValues[key] = value.value instanceof ethers.BigNumber ? value.value.toString() : value.value;
  }
  return eventDataValues;
}

function parseListingData(listing: { [key: string]: any }): { [key: string]: string | number } {
  const listingValues: { [key: string]: string | number } = {};
  for (const [key, value] of Object.entries(listing)) {
    if (isNaN(Number(key))) { // Exclude array indices
      listingValues[key] = (value as ethers.BigNumber | string | number) instanceof ethers.BigNumber ? (value as ethers.BigNumber).toString() : value as string | number;
    }
  }
  return listingValues;
}

function parseEventArguments(parsedEventData: { args: any }, eventFragment: { inputs: any[] }): { [key: string]: { type: any, value: any } } {
  const eventData: { [key: string]: { type: any, value: any } } = {};
  for (const [index, argValue] of Object.entries(parsedEventData.args).filter(([key]) => !isNaN(Number(key)))) {
    const argName = eventFragment.inputs[Number(index)].name;
    const argType = eventFragment.inputs[Number(index)].type;
    eventData[argName] = { type: argType, value: argValue };
  }
  return eventData;
}