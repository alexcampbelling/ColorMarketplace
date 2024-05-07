# Color Marketplace

## Description

This project is a marketplace built on the Story Layer 2 network. All Story Protocol native features of IP handling are ensured to be correctly dealt with during transfers.

## Alpha Warning

Please note that this project is currently in alpha. It is not recommended to use this in a production environment as there may be bugs and security vulnerabilities. All testing of this repo has been done on Linux, so if some commands do not work, I am sorry!

## How to Use

*First run `cp .env.example .env` and fill out the env vars you may need!!!*

This project uses npm scripts for task runs. Here's a list of the available scripts and what they do:

- `npm run lint-sol`: This script runs both the Solhint and Prettier scripts to lint and format the Solidity files.

- `npm run docgen`: This script generates documentation for the smart contracts using Hardhat Docgen.

- `npm run build`: This script compiles the smart contracts using Hardhat.

- `npm run local-test`: This script runs the test suite using Hardhat. It uses the hardhat runtime environment with taregt evm "Paris".

- `npm run testnet-test <market address>`: Will run the same tests as local on the given address. (Only for Sepolia atm)

- `npm run clean`: Removed local artifacts and cache directories for sanity checking solidity builds.

- `npm run clean-build`: Does the above and then builds

- `npm run deploy-sepolia`: Deploys current built contracts to the Sepolia testnet chain. Check the `scripts/deploy.ts` for details.

- `npm run flatten`: Flattens all solidity files into one file. This is just for verifying contracts on testnet, we should upload and verify via multiple files for launch.

## Todo



## License

This project is licensed under the [insert license here]. See the [LICENSE](LICENSE) file for details. (todo)


## Notes (to remove)
- "npm run testnet-test --address=your_contract_address" to specify deployed Color address for testing on testnet

npm run deploy-sepolia --contract_name=ColorMarketplace
npm run deploy-sepolia --contract_name=ColorNFT