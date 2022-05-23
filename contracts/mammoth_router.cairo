%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

# OZ
from contracts.lib.openzeppelin.contracts.Ownable_base import (
    Ownable_initializer, Ownable_only_owner, Ownable_get_owner, Ownable_transfer_ownership)
from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

# Mammoth
from contracts.lib.ratios.contracts.ratio import Ratio
from contracts.lib.Router_base import (
    Router_call_deposit, Router_call_withdraw, Router_call_swap, Router_create_pool,
    Router_only_approved_pool, Router_pool_approved)
from contracts.lib.Pool_registry_base import ApprovedERC20

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner_address : felt):
    Ownable_initializer(owner_address)
    return ()
end

############
# EVENTS
############

@event
func pool_created(
        pool : felt, swap_fee : Ratio, exit_fee : Ratio, tokens_len : felt,
        tokens : ApprovedERC20*):
end

@event
func deposit_called(token : felt, pool : felt, amount_deposited : Uint256):
end

@event
func withdraw_called(token : felt, pool : felt, amount_withdrawn : Uint256):
end

@event
func swap_called(token_in : felt, token_out : felt, pool : felt, amount_swapped_in : Uint256):
end

############
# CREATE POOL
############

@external
func create_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_address : felt, s_fee : Ratio, e_fee : Ratio, erc_list_len : felt,
        erc_list : ApprovedERC20*) -> (bool : felt):
    alloc_locals
    Ownable_only_owner()

    let (local success : felt) = Router_create_pool(
        pool_address, s_fee, e_fee, erc_list_len, erc_list)

    with_attr error_message("POOL CREATION FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end

    pool_created.emit(
        pool=pool_address,
        swap_fee=s_fee,
        exit_fee=e_fee,
        tokens_len=erc_list_len,
        tokens=erc_list)

    return (TRUE)
end

############
# DEPOSIT WITHDRAW SWAP
############

@external
func mammoth_deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, user_address : felt, pool_address : felt, erc20_address : felt) -> (
        success : felt):
    alloc_locals

    deposit_called.emit(token=erc20_address, pool=pool_address, amount_deposited=amount)

    Router_only_approved_pool(pool_address)
    let (local success : felt) = Router_call_deposit(
        amount, user_address, pool_address, erc20_address)

    with_attr error_message("DEPOSIT FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end
    return (TRUE)
end

@external
func mammoth_withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, user_address : felt, pool_address : felt, erc20_address : felt) -> (
        success : felt):
    alloc_locals

    withdraw_called.emit(token=erc20_address, pool=pool_address, amount_withdrawn=amount)

    Router_only_approved_pool(pool_address)
    let (local success : felt) = Router_call_withdraw(
        amount, user_address, pool_address, erc20_address)

    with_attr error_message("WITHDRAW FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end
    return (TRUE)
end

@external
func mammoth_swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, user_address : felt, pool_address : felt, erc20_address_in : felt,
        erc20_address_out : felt) -> (success : felt):
    alloc_locals

    swap_called.emit(
        token_in=erc20_address_in,
        token_out=erc20_address_out,
        pool=pool_address,
        amount_swapped_in=amount)

    Router_only_approved_pool(pool_address)
    let (local success : felt) = Router_call_swap(
        amount, user_address, pool_address, erc20_address_in, erc20_address_out)

    with_attr error_message("SWAP FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end

    return (TRUE)
end

#########
# OWNABLE
#########

@external
func get_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        owner : felt):
    let (owner) = Ownable_get_owner()
    return (owner=owner)
end

@external
func transfer_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_owner : felt) -> (new_owner : felt):
    Ownable_transfer_ownership(new_owner)
    return (new_owner=new_owner)
end

########
# VIEW
########

@view
func is_pool_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_address : felt) -> (bool : felt):
    alloc_locals
    let (local success : felt) = Router_pool_approved(pool_address)
    return (success)
end
