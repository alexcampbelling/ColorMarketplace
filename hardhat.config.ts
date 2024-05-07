import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import "hardhat-docgen";

import dotenv from "dotenv";

dotenv.config();

// Given this env var, we can chose if we compile the test contracts or the main contracts
// note: run "npm run clean-build" if only wanting to compile the main contracts (clearing possible artifacts from tests)
const isTestnet = process.env.HARDHAT_TEST === "true";

const config: HardhatUserConfig = {
  solidity: //"0.8.25",
  {
    version: "0.8.25",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1, // Needs this to be under the 24kb limit for contracts
      },
      "viaIR": true,
    }
  },
  // todo: use contractSizer plugin: https://www.npmjs.com/package/hardhat-contract-sizer
  // defaultNetwork: "sepolia", (todo: this makes tests run slowly then timeout, why?)
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: process.env.TEST_ENV === "local" ? "./contracts" : "./contracts/main",
    tests: "./tests",
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC,
      accounts: [`0x${process.env.DEPLOYER_PRIVATE_KEY}`],
    },
    storyTestnet: {
      url: process.env.STORY_PROTOCOL_TESTNET_RPC,
      accounts: [`0x${process.env.DEPLOYER_PRIVATE_KEY}`],
      chainId: 1513,
    },
  },
};

export default config;