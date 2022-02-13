# implements a register_pool function for writing all storage vars needed for a pool

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address
from contracts.lib.ratios.contracts.ratio import Ratio
from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

#approved erc20s
@storage_var
func approved_erc20s(erc20_address: felt) -> (bool: felt):
end

#store the address of the token contract
@storage_var
func lp_token_address() -> (contract_address: felt):
end

#pool weight of a given erc20 (1/w)
@storage_var
func token_weight(erc20_address: felt) -> (weight: Ratio):
end

#sum of all weights for normalization
@storage_var
func total_weight() -> (total_weight: Ratio):
end

#swap fee
@storage_var
func swap_fee() -> (fee: Ratio):
end

#exit fee
@storage_var
func exit_fee() -> (fee: Ratio):
end

########
#Structs
########

struct ApprovedERC20:
    member erc_address: felt
    member weight: Ratio*
end

func Register_initialize_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(lp_address: felt, s_fee: Ratio, e_fee: Ratio, erc_list_len: felt, erc_list: ApprovedERC20*) -> (bool: felt):

    lp_token_address.write(lp_address)
    swap_fee.write(s_fee)
    exit_fee.write(e_fee)
    _approve_ercs(erc_list_len, erc_list)
    return (TRUE)
end

func _approve_ercs{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(arr_len: felt, arr: ApprovedERC20*) -> (bool: felt):
    alloc_locals
    
    if arr_len == 0:
        return (TRUE)
    end

    let (local current_struct: ApprovedERC20) = [arr]
    approved_erc20s.write(current_struct.erc_address)
    token_weight.write(current_struct.erc20_address, current_struct.weight)

    _approve_ercs(arr_len - 1, arr + 1)

    return (TRUE)
end

func Register_get_pool_fees{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (s_fee: Ratio, e_fee: Ratio):
    alloc_locals

    local s: Ratio = swap_fee.read()
    local e: Ratio = exit_fee.read()

    return (s, e)
end

func Register_get_token_weight{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(erc_address: felt) -> (token_weight: Ratio):
    alloc_locals
    local tok_w: Ratio = token_weight.read(erc_address)
    return (tok_w)
end

func Register_get_total_weight{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (total_weight: Ratio):
    alloc_locals
    local t_w: Ratio = total_weight.read()
    return (t_w)
end

func Register_lp_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (lp_address: Ratio):
    alloc_locals
    local lp_address: felt = lp_token_address.read()
    return (lp_address)
end

