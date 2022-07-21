# mammoth_pool

Starknet pool similar to balancer v1 AMM

This repo uses cairo-nile https://github.com/OpenZeppelin/nile

# Goals:

- Users can deposit and withdraw any ERC-20 token into the contract any time they want
- Users get credited their yield when they withdraw from the contract
- The pool earns fees off swaps and some LP tokens may have additional staking rewards.

# CONTRACTS:

## ROUTER CONTRACT

### External

- mammoth_deposit_single_asset - deposit a single approved ERC20 to receive LP tokens (input Uint256)
- mammoth_proportional_deposit - deposit in proportion to current pool weights
- mammoth_withdraw_single_asset - withdraw a single ERC20 in exchange for LP tokens (input Uint256)
- mammoth_proportional_withdraw - withdraw in proportion to current pool weights
- mammoth_swap - swap one ERC20 for another ERC20 (input Uint256)
- create_pool - create new pool and provide initial liquidity

### View

- is_pool_approved - given pool address returns 1 if valid pool and 0 else

## POOL CONTRACT

### View

- view_out_given_in - given amount of ERC20 in and an ERC20 for out returns the amount of the second ERC20 a user would receive for inputing the amount in a swap
- view_in_given_out
- view_pool_minted_given_single_in - given amount of ERC20 in return amount of LP tokens minted
- view_single_in_given_pool_out
- view_single_out_given_pool_in - given amount of LP tokens in and ERC20 address returns amount of given ERC20 received for burning LP tokens
- view_pool_in_given_single_out
- get_ERC20_balance - given ERC20 address return balance of ERC20 in pool
- is_erc20_approved - given pool and ERC20 address returns 1 if ERC20 is approved for said pool else 0
- IMPLEMENTS ERC20_Mintable_Burnable

## TESTS
```
pytest tests
```

## DEPLOYMENT INSTRUCTIONS
start local devnet for default deployment
--network goerli for testnet deployment
--network mainnet for mainnet

- Set a private key variable in .env, for example PRIV_KEY=1
```
- nile setup PRIV_KEY
```
```
- fund your account with ETH (or testnet/devnet ETH)
```
```
- nile compile
```
```
- nile run scripts/testnet_fresh_deploy.py
```
```
- nile run scripts/approve_pool.py
```
```
- nile run scripts/create_pool.py
```
```
- nile run scripts/check_pool_creation.py
```

## POOL CREATION INSTRUCTIONS

- call create_pool on the router and provide list of ercs to include and initial liquidity amounts
- it is advisable to provide liquidity ina ratio similar to real prices
