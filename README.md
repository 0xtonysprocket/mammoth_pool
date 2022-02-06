# mammoth_pool
Starknet pool to provide non-custodial liquidity to order book market makers


Goals:

* Users can deposit and withdraw any ERC-20 token into the contract any time they want
* Whitelisted market makers can use the liquidity to call the fill_order function on the zigzag contract
* Users get paid a variable yield that can be updated by the owner of the contract
* Users get credited their yield when they withdraw from the contract

TODO:

* Test external MM calling fill_order with liquidity from pool
* Make "fill_order" method in proxy contract generalized for any potential exchange contract
* Create market maker vault mechanism
* Test balancer pools with multiple pools
* test out approved market maker trading

NOTE: testing currently incomplete
