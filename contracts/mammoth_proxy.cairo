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