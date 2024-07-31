# Color Marketplace

## Description

This project is a marketplace built on the Story Layer 2 network. All Story Protocol native features of IP handling are ensured to be correctly dealt with during transfers.

## How to Use

This project runs with foundry!

_First run `cp .env.example .env` and fill out the env vars you may need!!!_

`forge build`: Compiles all contracts needed
`forge test`: Runs all tests (add `-vvvv` for traces)
`forge script ColorMarketPlaceDeploy --rpc-url $SEPOLIA_RPC_URL --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast`: Deploy script for Sepolia, needing the correct environment variables!
