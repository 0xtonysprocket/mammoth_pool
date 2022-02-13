%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

# OZ
from contracts.lib.openzeppelin.contracts.Ownable_base import (
    Ownable_initializer,
    Ownable_only_owner,
    Ownable_get_owner,
    Ownable_transfer_ownership
)
from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

# Mammoth
from contracts.lib.ratios.contracts.ratio import Ratio
from contracts.lib.Router_base import (
    Router_call_deposit,
    Router_call_withdraw,
    Router_call_swap,
    Router_create_pool,
    Router_only_approved_pool,
    Router_pool_approved
)
from contracts.lib.Pool_registry_base import ApprovedERC20

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        owner_address: felt,
    ):
    Ownable_initializer(owner_address)
    return ()
end

############
# CREATE POOL
############

@external
func create_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt, s_fee: Ratio, e_fee: Ratio, erc_list_len: felt, erc_list: ApprovedERC20*) -> (bool: felt):
    alloc_locals
    Ownable_only_owner()

    let (local success: felt) = Router_create_pool(pool_address, s_fee, e_fee, erc_list_len, erc_list)
    assert success = TRUE
    return (TRUE)
end

############
# DEPOSIT WITHDRAW SWAP
############

@external
func mammoth_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt, pool_address: felt, erc20_address: felt) -> (success: felt):
    alloc_locals
    Router_only_approved_pool(pool_address)
    let (local success: felt) = Router_call_deposit(amount, address, pool_address, erc20_address)
    assert success = TRUE
    return (TRUE)
end

@external
func mammoth_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt, pool_address: felt, erc20_address: felt) -> (success: felt):
    alloc_locals
    Router_only_approved_pool(pool_address)
    let (local success: felt) = Router_call_withdraw(amount, address, pool_address, erc20_address)
    assert success = TRUE
    return (TRUE)
end

@external
func mammoth_swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt, pool_address: felt, erc20_address_in: felt, erc20_address_out: felt) -> (success: felt):
    alloc_locals
    Router_only_approved_pool(pool_address)
    let (local success: felt) = Router_call_swap(amount, address, pool_address, erc20_address_in, erc20_address_out)
    assert success = TRUE
    return (TRUE)
end

#########
# OWNABLE
#########

@external
func get_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = Ownable_get_owner()
    return (owner=owner)
end

@external
func transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt) -> (new_owner: felt):
    Ownable_transfer_ownership(new_owner)
    return (new_owner=new_owner)
end

########
#VIEW
########

@view
func is_pool_approved{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt) -> (bool: felt):
    alloc_locals
    let (local success: felt) = Router_pool_approved(pool_address)
    return (success)
end