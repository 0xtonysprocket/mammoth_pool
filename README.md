# mammoth_pool
Starknet pool to provide non-custodial liquidity to order book market makers


Goals:

* Users can deposit and withdraw any ERC-20 token into the contract any time they want
* Whitelisted market makers can use the liquidity to call the fill_order function on the zigzag contract - DONE
* Users get paid a variable yield that can be updated by the owner of the contract
* Users get credited their yield when they withdraw from the contract - DONE
* There should be some profit sharing mechanism between MMs and LPs
