# Color Marketplace

## Description

This project is a marketplace built on the Story Layer 2 network. All Story Protocol native features of IP handling are ensured to be correctly dealt with during transfers.

## Alpha Warning

Please note that this project is currently in alpha. It is not recommended to use this in a production environment as there may be bugs and security vulnerabilities. All testing of this repo has been done on Linux, so if some commands do not work, I am sorry!

## How to Use

This project runs with foundry!

*First run `cp .env.example .env` and fill out the env vars you may need!!!*

`forge build`: Compiles all contracts needed
`forge test`: Runs all tests (add `-vvv` for traces)
`forge script ColorMarketPlaceDeploy --rpc-url $SEPOLIA_RPC_URL --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast`: Deply script for Sepolia, needing the correct environment variables!
