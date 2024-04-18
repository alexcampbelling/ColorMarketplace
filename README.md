# Color Marketplace

## Description

This project is a marketplace built on the Story Layer 2 network. All Story Protocol native features of IP handling are ensured to be correctly dealt with during transfers.

## Alpha Warning

Please note that this project is currently in alpha. It is not recommended to use this in a production environment as there may be bugs and security vulnerabilities.

## How to Use

This project uses npm scripts for task automation. Here's a list of the available scripts and what they do:

- `npm run lint-sol`: This script runs both the Solhint and Prettier scripts to lint and format the Solidity files.

- `npm run docgen`: This script generates documentation for the smart contracts using Hardhat Docgen.

- `npm run build`: This script compiles the smart contracts using Hardhat.

- `npm run test`: This script runs the test suite using Hardhat.

To run a script, open your terminal, navigate to the project directory, and enter the command for the script. For example, to run the `build` script, you would enter `npm run build`.

## Todo

- Licensing
- Deployment scripts
- Contract interaction scripts
- .env file
- Configure Hardhat to test on actual node instead of runtime
- Finish basic tests for marketplace
- Payable vs nonpayable, ensure I got it all down fine

## License

This project is licensed under the [insert license here]. See the [LICENSE](LICENSE) file for details. (todo)