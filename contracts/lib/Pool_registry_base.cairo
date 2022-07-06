# implements a register_pool function for writing all storage vars needed for a pool

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le

# local
from contracts.lib.ratios.contracts.ratio import Ratio, ratio_add
from contracts.lib.Pool_base import Pool

# OZ
from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

# approved erc20s
@storage_var
func approved_erc20s(erc20_address : felt) -> (bool : felt):
end

# pool weight of a given erc20 (1/w)
@storage_var
func token_weight(erc20_address : felt) -> (weight : Ratio):
end

# sum of all weights for normalization
@storage_var
func total_weight() -> (total_weight : Ratio):
end

# swap fee
@storage_var
func swap_fee() -> (fee : Ratio):
end

# exit fee
@storage_var
func exit_fee() -> (fee : Ratio):
end

# number of tokens
@storage_var
func num_tokens() -> (num_tokens : felt):
end

@storage_var
func indexed_approved_ercs(index : felt) -> (erc_address : felt):
end

########
# Structs
########

struct ApprovedERC20:
    member erc_address : felt
    member low_num : felt
    member high_num : felt
    member low_den : felt
    member high_den : felt
    member initial_liquidity_low : felt
    member initial_liquidity_high : felt
end

namespace Register:
    func initialize_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            caller_address : felt, s_fee : Ratio, e_fee : Ratio, erc_list_len : felt,
            erc_list : ApprovedERC20*) -> (bool : felt, lp_amount : Uint256):
        alloc_locals

        # needed for dereferencing struct
        let (__fp__, _) = get_fp_and_pc()

        swap_fee.write(s_fee)
        exit_fee.write(e_fee)
        num_tokens.write(erc_list_len)

        local _lp_amount : Uint256 = Uint256(0, 0)
        let (local t_weight : Ratio, local lp_amount : Uint256) = _approve_ercs(
            caller_address, _lp_amount, erc_list_len, erc_list)

        # check weights are normalized
        let (local eq : felt) = uint256_eq(t_weight.n, t_weight.d)
        assert eq = 1

        total_weight.write(Ratio(Uint256(1, 0), Uint256(1, 0)))
        return (TRUE, lp_amount)
    end

    func _approve_ercs{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            caller_address : felt, _lp_amount : Uint256, arr_len : felt, arr : ApprovedERC20*) -> (
            weight_sum : Ratio, lp_amount : Uint256):
        alloc_locals

        # needed for dereferencing struct
        let (__fp__, _) = get_fp_and_pc()

        if arr_len == 0:
            return (Ratio(Uint256(0, 0), Uint256(1, 0)), _lp_amount)
        end

        let current_struct : ApprovedERC20* = [&arr]
        local weight : Ratio = Ratio(Uint256(current_struct.low_num, current_struct.high_num), Uint256(current_struct.low_den, current_struct.high_den))

        approved_erc20s.write(current_struct.erc_address, TRUE)
        token_weight.write(current_struct.erc_address, weight)
        indexed_approved_ercs.write(arr_len - 1, current_struct.erc_address)

        local amount : Uint256 = Uint256(
            current_struct.initial_liquidity_low, current_struct.initial_liquidity_high)

        let (local success : felt) = Pool.deposit(
            amount, caller_address, current_struct.erc_address)

        let (local le : felt) = uint256_le(_lp_amount, amount)

        # make two separate branches  to avoid variable dereferencing on _lp_amount
        if le == 1:
            local _lp_amount : Uint256 = amount
            let (local rest_of_sum : Ratio, lp_amount : Uint256) = _approve_ercs(
                caller_address, _lp_amount, arr_len - 1, arr + ApprovedERC20.SIZE)
            let (local weight_sum : Ratio) = ratio_add(weight, rest_of_sum)

            return (weight_sum, lp_amount)
        else:
            let (local rest_of_sum : Ratio, lp_amount : Uint256) = _approve_ercs(
                caller_address, _lp_amount, arr_len - 1, arr + ApprovedERC20.SIZE)
            let (local weight_sum : Ratio) = ratio_add(weight, rest_of_sum)

            return (weight_sum, lp_amount)
        end
    end

    func get_pool_info{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
            s_fee : Ratio, e_fee : Ratio, tot_weight : Ratio):
        alloc_locals

        let (local s : Ratio) = swap_fee.read()
        let (local e : Ratio) = exit_fee.read()
        let (local t_w : Ratio) = total_weight.read()

        return (s, e, t_w)
    end

    func get_token_weight{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            erc_address : felt) -> (token_weight : Ratio):
        alloc_locals
        let (local tok_w : Ratio) = token_weight.read(erc_address)
        return (tok_w)
    end

    func only_approved_erc20{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            erc20_address : felt):
        let (approval : felt) = approved_erc20s.read(erc20_address)
        assert approval = TRUE
        return ()
    end

    func is_erc20_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            erc20_address : felt) -> (approval : felt):
        let (approval : felt) = approved_erc20s.read(erc20_address)
        return (approval)
    end

    func get_num_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
            num : felt):
        alloc_locals

        let (local num : felt) = num_tokens.read()
        return (num)
    end

    func get_exit_fee{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
            fee : Ratio):
        alloc_locals

        let (local fee : Ratio) = exit_fee.read()
        return (fee)
    end

    func get_approved_erc_from_index{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(index : felt) -> (
            erc : felt):
        alloc_locals

        let (local e : felt) = indexed_approved_ercs.read(index)
        return (e)
    end
end
