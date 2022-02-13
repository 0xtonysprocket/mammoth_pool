#Mammoth pool contract allowing following functionality:
#1. Deposit tokens
#2. Withdraw tokens
#3. whitelisted MM access to atomic swaps with liquidity
#4. controls on trades that can be executed
#5. view token balance

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.uint256 import Uint256

from contracts.lib.openzeppelin.contracts.Ownable_base import (
    Ownable_initializer,
    Ownable_only_owner,
    Ownable_get_owner,
    Ownable_transfer_ownership
)
from contracts.lib.openzeppelin.contracts.Initializable import ( initialize, initialized )

from contracts.lib.Pool_base import ( Pool_deposit, Pool_withdraw )
from contracts.lib.Pool_registry_base import (
    Register_initialize_pool,
    Register_get_pool_info,
    Register_get_token_weight,
    Register_only_approved_erc20
    )
from contracts.lib.balancer_math import (
    get_out_given_in,
    get_pool_minted_given_single_in,
    get_single_out_given_pool_in,
    )

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(router: felt):
    Ownable_initializer(router)
    return ()
end

##########
#POOL FUNCTIONS
##########

@external
func deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_to_deposit: Uint256, address: felt, erc20_address: felt) -> (pool_amount_to_mint: Uint256):
    alloc_locals
    Register_only_approved_erc20(erc20_address)

    let (local pool_amount_to_mint: Uint256) = view_pool_minted_given_single_in(amount, erc20_address)
    let (local success: felt) = Pool_deposit(amount_to_deposit, address, erc20_address)
    assert success = TRUE

    return (pool_amount_to_mint)
end

@external
func withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_amount_in: Uint256, address: felt, erc20_address: felt) -> (amount_out: Uint256):
    alloc_locals
    Register_only_approved_erc20(erc20_address)

    let (local amount_out: Uint256) = view_single_out_given_pool_in(pool_amount_in, erc20_address)
    let (local success: felt) = Pool_withdraw(amount_out, address, erc20_address)
    assert success = TRUE

    return (TRUE)
end

@external
func initialize_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(lp_address: felt, s_fee: Ratio, e_fee: Ratio, erc_list_len: felt, erc_list: ApprovedERC20*) -> (bool: felt):
    alloc_locals

    let (local success: felt) = Register_initialize_pool(lp_address, s_fee, e_fee, erc_list_len, erc_list)
    assert success = TRUE

    initialize()
    
    return (TRUE)
end

##########
#VIEW MATH
##########

@view
func view_single_out_given_pool_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_amount_in: felt, erc20_address: felt) -> (amount_to_withdraw: felt):
end

@view
func view_pool_minted_given_single_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_to_deposit: felt, erc20_address: felt) -> (amount_to_withdraw: felt):
end

@view
func view_out_given_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_in: felt, erc20_address_in: felt, erc20_address_out: felt) -> (amount_out: felt):
end