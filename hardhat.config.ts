import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import "hardhat-docgen";

import dotenv from "dotenv";

dotenv.config();

// Given this env var, we can chose if we compile the test contracts or the main contracts
// note: run "npm run clean-build" if only wanting to compile the main contracts (clearing possible artifacts from tests)
const isTest = process.env.HARDHAT_TEST === "true";

const config: HardhatUserConfig = {
  solidity: "0.8.25",
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: isTest ? "./contracts" : "./contracts/main",
    tests: "./test",
  },
  networks: {
    testnet: {
      url: process.env.STORY_PROTOCOL_RPC_TEST,
      accounts: [`0x${process.env.DEPLOYER_PRIVATE_KEY}`],
    },
    mainnet: {
      url: process.env.STORY_PROTOCOL_RPC_MAIN,
      accounts: [`0x${process.env.DEPLOYER_PRIVATE_KEY}`],
    },
  },
};

export default config;