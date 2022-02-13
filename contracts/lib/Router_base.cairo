# implements the following:
#
# ON ERC20
# call_burn
# call_mint
#
# ON POOL
# call_deposit  
# call_withdraw

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IERC20:
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func decimals() -> (decimals: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end
end

@contract_interface
namespace IPoolContract:
    func deposit(amount: Uint256, address: felt, erc20_address: felt):
    end

    func withdraw(amount: Uint256, address: felt, erc20_address: felt):
    end

    func get_ERC20_balance(erc20_address: felt) -> (res: Uint256):
    end
end

#store the address of the pool contract
@storage_var
func approved_pool_address(pool_address: felt) -> (bool: felt):
end

func Router_call_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
    pool_address: felt,
    lp_address: felt,
    recipient: felt, 
    amount: Uint256):
    IERC20.mint(contract_address=lp_address, recipient=recipient, amount=amount)
    return ()
end

func Router_call_burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pool_address: felt,
    lp_address: felt,
    recipient: felt, 
    amount: Uint256):
    IERC20.burn(contract_address=lp_address, user=recipient, amount=amount)
    return ()
end

func Router_call_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, pool_address: felt, erc20_address: felt):
    IERC20.deposit(contract_address=pool_address, amount=amount, address=address, erc20_address=erc20_address)
    return ()
end

func Router_call_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, pool_address: felt, erc20_address: felt):
    IERC20.withdraw(contract_address=pool_address, amount=amount, address=address, erc20_address=erc20_address)
    return ()
end

func Router_create_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(lp_address: felt, pool_address: felt, s_fee: Ratio, e_fee: Ratio):
    Ownable_only_owner()

    approved_pool_address.write(pool_address, 1)
    lp_token_address.write(pool_address, lp_address)
    swap_fee.write(pool_address, s_fee)
    exit_fee.write(pool_address, e_fee)
    return ()
end