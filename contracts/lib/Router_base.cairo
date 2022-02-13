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
from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

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

@contract_interface
namespace IPoolRegister:
    func Register_initialize_pool(lp_address: felt, s_fee: Ratio, e_fee: Ratio, erc_list_len: felt, erc_list: ApprovedERC20*) -> (bool: felt):
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
    _only_approved_pool(pool_address)
    IERC20.mint(contract_address=lp_address, recipient=recipient, amount=amount)
    return ()
end

func Router_call_burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pool_address: felt,
    lp_address: felt,
    recipient: felt, 
    amount: Uint256):
    _only_approved_pool(pool_address)
    IERC20.burn(contract_address=lp_address, user=recipient, amount=amount)
    return ()
end

func Router_call_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, pool_address: felt, erc20_address: felt):
    _only_approved_pool(pool_address)
    IERC20.deposit(contract_address=pool_address, amount=amount, address=address, erc20_address=erc20_address)
    return ()
end

func Router_call_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, pool_address: felt, erc20_address: felt):
    _only_approved_pool(pool_address)
    IERC20.withdraw(contract_address=pool_address, amount=amount, address=address, erc20_address=erc20_address)
    return ()
end

func Router_create_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt, lp_address: felt, s_fee: Ratio, e_fee: Ratio, erc_list_len: felt, erc_list: ApprovedERC20*) -> (bool: felt):
    approved_pool_address.write(pool_address, TRUE)
    IPoolRegister.Register_initialize_pool(contract_address=pool_address, lp_address=lp_address, s_fee=s_fee, e_fee=e_fee, erc_list_len=erc_list_len, erc_list=erc_list)
    return (TRUE)
end

func _only_approved_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt):
    alloc_locals

    local approved: felt = approved_pool_address.read(pool_address)
    assert approved = TRUE

    return ()
end
