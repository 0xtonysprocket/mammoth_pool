# mammoth_pool
Starknet pool to provide non-custodial liquidity to order book market makers

# Goals:

* Users can deposit and withdraw any ERC-20 token into the contract any time they want
* Whitelisted market makers can use the liquidity to call the fill_order function on the zigzag contract
* Users get paid a variable yield that can be updated by the owner of the contract
* Users get credited their yield when they withdraw from the contract

# TODO:

* Test external MM calling fill_order with liquidity from pool
* Make "fill_order" method in proxy contract generalized for any potential exchange contract
* Create market maker vault mechanism
* Test balancer pools with multiple pools
* test out approved market maker trading
* Convert everything to Uint256

NOTE: testing currently incomplete

# CONTRACTS:

## PROXY CONTRACT

### External

* mammoth_deposit - deposit a single approved ERC20 to receive LP tokens
* mammoth_withdraw - withdraw a single ERC20 in exchange for LP tokens
* mammoth_swap - swap one ERC20 for another ERC20
* create_pool - create new pool
* add_approved_erc20_for_pool
* approve_market_maker_contract_address

### View

* get_token_address_for_pool - given pool address returns LP token address
* get_swap_fee_for_pool - given pool address returns current swap fee
* get_exit_fee_for_pool - given pool address returns current exit fee
* is_pool_approved - given pool address returns 1 if valid pool and 0 else
* is_erc20_approved - given pool and ERC20 address returns 1 if ERC20 is approved for said pool else 0
* get_weight_for_token - given pool and ERC20 address returns weight of ERC20 token in pool
* view_out_given_in - given amount of ERC20 in and an ERC20 for out returns the amount of the second ERC20 a user would receive for inputing the amount in a swap
* view_pool_minted_given_single_in - given amount of ERC20 in return amount of LP tokens minted
* view_single_out_given_pool_in - given amount of LP tokens in and ERC20 address returns amount of given ERC20 received for burning LP tokens

## POOL CONTRACT

### View

* get_ERC20_balance - given ERC20 address return balance of ERC20 in pool

## LP Token CONTRACT

### View

* all normal methods for ERC 20

## DEPLOYMENT INSTRUCTIONS

* Set STARKNET_NETWORK and PRIV_KEY variables in .env
* run *python deploy_account.py* or set current_account.json manually
* run *python compile_contracts.py* from root
* run *python deploy_contracts.py* from root

## INFO

* Find the current owner account in *current_account.json*
* Find the current contract addresses in *current_deployment_info.json*