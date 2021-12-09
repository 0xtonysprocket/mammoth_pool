# mammoth_pool
Starknet pool to provide non-custodial liquidity to order book market makers


Goals:

* Users can deposit and withdraw any ERC-20 token into the contract any time they want
* Whitelisted market makers can use the liquidity to call the fill_order function on the zigzag contract
* Users get paid a variable yield that can be updated by the owner of the contract
* Users get credited their yield when they withdraw from the contract
* There should be some profit sharing mechanism between MMs and LPs

TODO:

* Make any ERC20 depositable in the pool
* Assign balances to the proxy contract instead of pool contract so it is UPGRADEABLE
* Have the LP contract mint LP tokens that are different for different liquidity provided
* Test external MM calling fill_order with liquidity from pool
* Implement profit share mechanism
