# proxy contract for depositing to Mammoth pool and receiving LP tokens
#also proxy for whitelised MM

#whitelist MM in storage var
#allow MM to call fill_order from zigzag contract with liquidity from mammoth_pool

@contract_interface
namespace ITokenContract:
    func proxy_mint(recipient: felt, amount: Uint256):
    end

    func proxy_burn(user: felt, amount: Uint256):
    end
end

#store the address of the token contract
@storage_var
func token_address() -> (contract_address: felt):
end

#store the address of the pool contract
@storage_var
func pool_address() -> (contract_address: felt):
end

@storage_var
func market_maker_address() -> (market_maker_address: felt);
end

func call_mint{syscall_ptr: felt*, range_check_ptr}(
    contract_address:felt, recipient:felt, amount: Uint256):
    let (c) = token_address.read()
    ITokenContract.proxy_mint(conract_address=c, recipient=recipient, amount=amount)
end

func call_burn{syscall_ptr: felt*, range_check_ptr}(
    contract_address:felt, recipient:felt, amount: Uint256):
    let (c) = token_address.read()
    ITokenContract.proxy_burn(contract_address=c, recipient=recipient, amount=amount)
end

##########
#FUNCTIONALITY TO BE IMPLEMENTED FOR DEPOSIT AND WITHDRAWAL
##########

#func call_deposit
#input (amount, address)

#IPoolContract.proxy_deposit(amount, address)
#END

#func call_withdraw
#input (amount, address)

#IPoolContract.proxy_withdraw(amount, address)
#END

#func mammoth_deposit
#input (amount, address)

#call_deposit(amount, address)
#call_mint(amount, address)
#END

#func mammoth_withdraw
#input (amount, address)

#get caller address
#call_withdraw(amount, address)
#call_burn(amount, address)
#END

##########
##########
