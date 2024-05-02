import { ethers, network } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  const networkName = network.name;

  console.log(`Deploying on: ${networkName}`);

  const [deployer] = await ethers.getSigners();

  // const contractName = process.env.CONTRACT_NAME;
  const contractName = process.env.npm_config_contract_name;

  console.log(
    `Deploying ${contractName} on ${networkName} with the account:`,
    deployer.address
  );

  if (contractName === "ColorMarketplace") {
    const ColorMarketplace = await ethers.getContractFactory("ColorMarketplace");
    const colorMarketplace = await ColorMarketplace.deploy();
    console.log("ColorMarketplace contract address:", colorMarketplace.address);
  } else if (contractName === "ColorNFT") {
    const ColorNFT = await ethers.getContractFactory("ColorNFT");
    const colorNFT = await ColorNFT.deploy();
    console.log("ColorNFT contract address:", colorNFT.address);
  } else {
    console.error("CONTRACT_NAME environment variable is not set or invalid");
    process.exit(1);
  }

  console.log("Account balance left:", (await deployer.getBalance()).toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });