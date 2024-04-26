import { ethers, network } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

const CONTRACT_NAME = "ColorMarketplace";

async function main() {
  const networkName = network.name;

  console.log(`Deploying on: ${networkName}`);

  const [deployer] = await ethers.getSigners();

  console.log(
    `Deploying ${CONTRACT_NAME} on ${networkName} with the account:`,
    deployer.address
  );

  console.log("Account balance:", (await deployer.getBalance()).toString()); // todo, get this out of gwei

  const Contract = await ethers.getContractFactory(CONTRACT_NAME);
  const contract = await Contract.deploy();

  console.log("Contract address:", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });