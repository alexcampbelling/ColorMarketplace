import hre from "hardhat";
import { expect } from "chai";
import { ethers } from "ethers";
import dotenv from 'dotenv';

dotenv.config();


// For interacting with Color contract
enum TokenType {
  ERC721 = 0,
  ERC1155 = 1
}

describe("Color Marketplace Testing", function () {
  let ColorMarket: ethers.Contract;
  let ColorNFT: ethers.Contract;

  const ENV = process.env.TEST_ENV;

  before(async function () {
    try {
      if (ENV === "local") {
        // Deploy market to hre
        ColorMarket = await hre.ethers.deployContract("ColorMarketplace");
        // Deploy the NFT contract
        ColorNFT = await hre.ethers.deployContract("ColorNFT");
      } else if (ENV === "testnet") {
        const contractAddress = process.env.COLOR_SEPOLIA_ADDRESS;
        const nftContractAddress = process.env.TEST_NFT_ADDRESS;
        if (!contractAddress || !nftContractAddress) {
          console.error("CONTRACT_ADDRESS or NFT_CONTRACT_ADDRESS environment variable is not set");
          process.exit(1);
        }
        // Connect to the deployed contracts
        ColorMarket = await hre.ethers.getContractAt("ColorMarketplace", contractAddress);
        ColorNFT = await hre.ethers.getContractAt("ColorNFT", nftContractAddress);

        // Sanity log these for the user
        console.log("Color contract Address:", contractAddress, "Test NFT Contract Address:", nftContractAddress);
      } else {
        console.log("No environment specified, please set TEST_ENV to 'local' or 'testnet' in .env file or in command line arguments.")
        process.exit(1);
      }
      // Sanity log these for the user
      console.log("Color contract Address:", ColorMarket.address, "Test NFT Contract Address:", ColorNFT.address);
    } catch (error) {
      console.error("Failed to initialize contracts:", error);
      process.exit(1);
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

      // todo: if environment is on-chain, check bytecode is what we expect, 
      // or throw error and tell user to redeploy with updated contract to test against
    });

    it("Market deployed to target address");

    it("Basic variable reads on the market can be done"); // Get the name, version, listings, etc.

    it("Check all feature public functions are reachable");

    it("Check all internal functions are not reachable");

    it("todo: add proxy upgrade functionality checks");
  })

  describe("Basic feature checks", async function() {
    it("Mint 721 NFT and list on market", async function () {
      // Set up
      const [owner] = await hre.ethers.getSigners();
      const price = ethers.utils.parseEther("1"); // Set the price to 1 ETH
  
      // Mint the NFT and get the tokenId
      const tokenURI: string = "ipfs://...";
      const tokenId: number = await mintNFT(owner, ColorNFT, tokenURI);

      // Check that the marketplace contract is approved to manage the token
      const isApproved = await approveMarketplace(owner, ColorNFT, ColorMarket);
      expect(isApproved.status).to.equal(1);
      
      // List the NFT on the market and get the listingId
      const listingId = await listOnMarket(owner, ColorMarket, TokenType.ERC721, ColorNFT.address, tokenId, price, 1);
  
      // Check that the NFT is listed on the market
      const isListed: boolean = await ColorMarket.listingExistsById(listingId);
      expect(isListed).to.be.true;
  
      // Check that the NFT is owned by the market contract
      await checkOwnership(ColorNFT, tokenId, ColorMarket.address);
    });
  
    it("Mint 1155 NFT and list on market");
  
    it("Batch listings correctly list", async function () {
      const [owner] = await hre.ethers.getSigners();
      const tokenIds: number[] = [await mintNFT(owner, ColorNFT, ""), await mintNFT(owner, ColorNFT, "")];
      await approveMarketplace(owner, ColorNFT, ColorMarket);
    
      const tokenTypes = [TokenType.ERC721, TokenType.ERC721];
      const contractAddresses = [ColorNFT.address, ColorNFT.address];
      const prices = [ethers.utils.parseEther("1"), ethers.utils.parseEther("2")];
      const amounts = [1, 1];
    
      // List batch items
      await ColorMarket.connect(owner).listBatchItems(tokenTypes, contractAddresses, tokenIds, prices, amounts);
    
      // Check that the listings have been created
      for (let i = 0; i < tokenIds.length; i++) {
        const listing = await ColorMarket.getListingDetailsById(i + 1); // Assuming listing IDs start from 1
        expect(listing.tokenType).to.equal(tokenTypes[i]);
        expect(listing.contractAddress).to.equal(contractAddresses[i]);
        expect(listing.tokenId.eq(tokenIds[i])).to.be.true;
        expect(listing.price.eq(prices[i])).to.be.true;
        expect(listing.availableAmount.toNumber()).to.equal(amounts[i]);
      }
    });

    it("Remove listing", async function () {
      const [owner] = await hre.ethers.getSigners();
      const tokenId: number = await mintNFT(owner, ColorNFT, "");
      await approveMarketplace(owner, ColorNFT, ColorMarket);
      const listingId = await listOnMarket(owner, ColorMarket, TokenType.ERC721, ColorNFT.address, tokenId, ethers.utils.parseEther("1"), 1);
      const isListed: boolean = await ColorMarket.listingExistsById(listingId);
      expect(isListed).to.be.true;
      await ColorMarket.connect(owner).removeListItem(listingId);
      const isStillListed: boolean = await ColorMarket.listingExistsById(listingId);
      expect(isStillListed).to.be.false;
    });

    it("Purchase listing", async function () {
      try {
        // Set up
        const price = ethers.utils.parseEther("1"); // Set the price to 1 ETH
    
        // Get the owner and another account
        const [owner, buyer] = await hre.ethers.getSigners();
    
        // Assume the NFT with tokenId 0 was minted and listed in the previous test
        const tokenId = 1;
        const listingId = 0; // Assuming the listingId is 0
        const amount = 1; // Assuming you're purchasing 1 token
    
        // Get the initial balance of the buyer
        const initialBalance = await buyer.getBalance();

        // Purchase the listing
        const buyTx = await ColorMarket.connect(buyer).purchaseListing(listingId, amount, { value: price });

        // Calculate the total gas cost
        const totalGasCost = (await buyTx.wait()).gasUsed.mul((await hre.ethers.provider.getTransaction(buyTx.hash)).gasPrice);

        // Get the final balance of the buyer
        const finalBalance = await buyer.getBalance();

        // console.log("Price: ", price.toString());
        // console.log("Initial Balance: ", initialBalance.toString());
        // console.log("Final Balance: ", finalBalance.toString());
        // console.log("Difference: ", initialBalance.sub(finalBalance).toString());

        // Check that the buyer's balance decreased by the price of the listing
        expect(initialBalance.sub(finalBalance).eq(price.add(totalGasCost))).to.be.true;

        // Check that the NFT was transferred to the buyer
        const ownerOfToken = await ColorNFT.ownerOf(tokenId);
        expect(ownerOfToken).to.equal(buyer.address);
    
        // Check that the listing does not exist after purchase
        expect(await ColorMarket.listingExistsById(listingId)).to.be.false;
      } catch (error) {
        console.error(`Error occurred in "Purchase listing":`, error);
        throw error;
      }
    });

    it("Update listing price", async function () {
      const [owner] = await hre.ethers.getSigners();
      const tokenId: number = await mintNFT(owner, ColorNFT, "");
      await approveMarketplace(owner, ColorNFT, ColorMarket);
      const listingId = await listOnMarket(owner, ColorMarket, TokenType.ERC721, ColorNFT.address, tokenId, ethers.utils.parseEther("1"), 1);
      const newPrice = ethers.utils.parseEther("2");
      await ColorMarket.connect(owner).updateListingPrice(listingId, newPrice);
      const listing = await ColorMarket.getListingDetailsById(listingId);
      expect(listing.price.eq(newPrice)).to.be.true;
    });

    it("Listing expiration check");

    it("Listing not available", async function () {
      const [owner] = await hre.ethers.getSigners();
      const tokenId: number = await mintNFT(owner, ColorNFT, "");
      await approveMarketplace(owner, ColorNFT, ColorMarket);
      const listingId = await listOnMarket(owner, ColorMarket, TokenType.ERC721, ColorNFT.address, tokenId, ethers.utils.parseEther("1"), 1);
      
      // Remove the listing
      await ColorMarket.connect(owner).removeListItem(listingId);
    
      // Check that the listing is not available
      const isStillListed: boolean = await ColorMarket.listingExistsById(listingId);
      expect(isStillListed).to.be.false;
    });
  
    it("Only can buy with $STORY token");
    
    // todo: add auction functionality and tests
  })

  describe("Story protocol specific checks", async function() {
    it("IP Account for NFT found");

    it("License tokens found and listed");

    it("Modules found and listed");

    it("IP or Module changed");

    it("IP asset remixed for listed NFT")
  })

  describe("Custom error checks", function() {
    // todo: need to think about the code paths to get to each of these (coverage)
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


// Helper function to mint an NFT
async function mintNFT(owner: ethers.Signer, contractInstance: ethers.Contract, tokenURI: string): Promise<number> {
  const mintTx = await contractInstance.connect(owner).mint(tokenURI);
  const receipt = await mintTx.wait();
  const NFTMintedEvent = findEventByName(receipt, 'NFTMinted');
  const newItemId = NFTMintedEvent?.args?.[0];
  return newItemId;
}


// Helper function to list an NFT on the market
async function listOnMarket(seller: ethers.Signer, contractInstance: ethers.Contract, tokenType: number, contractAddress: string, tokenId: number, price: ethers.BigNumber, amount: number): Promise<number> {
  const listingTx = await contractInstance.connect(seller).createListing(tokenType, contractAddress, tokenId, price, amount);
  const receipt = await listingTx.wait();
  const ListingCreatedEvent = receipt.events?.find((event: any) => event.event === "ListingCreated");
  const listingId = ListingCreatedEvent?.args?.listingId;
  return listingId;
}

// Helper function to check the owner of an NFT
async function checkOwnership(contractInstance: ethers.Contract, tokenId: number, expectedOwner: string): Promise<void> {
  const owner: string = await contractInstance.ownerOf(tokenId);
  expect(owner).to.equal(expectedOwner);
}

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

  return await mintTx.wait();
}

async function approveMarketplace(account: ethers.Signer, nftContract: ethers.Contract, market: ethers.Contract): Promise<ethers.ContractReceipt> {
  // Connect the NFT contract with the account
  const nftContractWithSigner = nftContract.connect(account);

  // Approve the marketplace contract to manage all tokens
  const approvalTx = await nftContractWithSigner.setApprovalForAll(market.address, true);

  return await approvalTx.wait();
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