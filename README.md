# Color Marketplace

## Description

This project is a marketplace built on the Story Layer 2 network. All Story Protocol native features of IP handling are ensured to be correctly dealt with during transfers.

## Alpha Warning

Please note that this project is currently in alpha. It is not recommended to use this in a production environment as there may be bugs and security vulnerabilities. All testing of this repo has been done on Linux, so if some commands do not work, I am sorry!

## How to Use

*First run `cp .env.example .env` and fill out the env vars you may need!!!*

This project uses npm scripts for task automation. Here's a list of the available scripts and what they do:

- `npm run lint-sol`: This script runs both the Solhint and Prettier scripts to lint and format the Solidity files.

- `npm run docgen`: This script generates documentation for the smart contracts using Hardhat Docgen.

- `npm run build`: This script compiles the smart contracts using Hardhat.

- `npm run test`: This script runs the test suite using Hardhat.

- `npm run deploy-testnet`: Deploys market code to testnet via hardhat

- `npm run deploy-mainnet`: NOT IMPLEMENTED

To run a script, open your terminal, navigate to the project directory, and enter the command for the script. For example, to run the `build` script, you would enter `npm run build`.

## Todo

- Licensing
- Payable vs nonpayable, ensure I got it all down fine
- Consider Forge testing (for fuzzing and tracing, but more overhead to get this started where hardhat works already)
  - Maybe do business / integration tests in hardhat, and fuzzing / unit tests in forge


## License

This project is licensed under the [insert license here]. See the [LICENSE](LICENSE) file for details. (todo)



## Notes (remove)
- "npm run testnet-test --address=your_contract_address" to specify deployed Color address for testing on testnet

npm run deploy-sepolia --contract_name=ColorMarketplace
npm run deploy-sepolia --contract_name=ColorNFT