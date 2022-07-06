%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math import assert_not_zero, assert_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_mul, uint256_le, uint256_lt,
    uint256_unsigned_div_rem)

from contracts.lib.ratios.contracts.ratio import (
    Ratio, ratio_mul, ratio_div, ratio_add, ratio_diff, nth_root_by_digit, pow, ratio_pow,
    ratio_less_than_or_eq)

#########
# STRUCT
#########

struct TokenAndAmount:
    member erc_address : felt
    member amount : Uint256
end

#########
# BALANCER STYLE MATH
# CONSTANT VALUE INVARIANT
#########

# Cairo implementation of https://github.com/balancer-labs/balancer-core/blob/master/contracts/BMath.sol

namespace Balancer_Math:
    #
    #   a_balance/a_weight          fee.denominator
    #           /               *           /
    #   b_balance/b_weight          fee.denominator - fee.numerator
    #
    @view
    func get_spot_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            a_balance : Uint256, a_weight : Ratio, b_balance : Uint256, b_weight : Ratio,
            fee : Ratio) -> (spot_price : Ratio):
        alloc_locals

        # needed for dereferencing ratios
        let (__fp__, _) = get_fp_and_pc()

        let (local x : Uint256, _) = uint256_mul(a_balance, a_weight.n)
        let (local y : Uint256, _) = uint256_mul(b_balance, b_weight.n)
        let fee_adj : Uint256 = uint256_sub(fee.d, fee.n)

        local num_ratio : Ratio = Ratio(n=x, d=a_weight.d)
        local den_ratio : Ratio = Ratio(n=y, d=b_weight.d)

        let (local z : Uint256, _) = uint256_mul(num_ratio.n, den_ratio.d)
        let (local z_fee : Uint256, _) = uint256_mul(z, fee.d)
        let (local k : Uint256, _) = uint256_mul(den_ratio.n, num_ratio.d)
        let (local k_fee : Uint256, _) = uint256_mul(fee_adj, k)

        local spot_price : Ratio = Ratio(n=z_fee, d=k_fee)

        return (spot_price)
    end

    ###########################
    # DEPOSITS AND WITHDRAWALS
    ###########################

    # **********************************************************************************************
    # calcPoolOutGivenSingleIn                                                                  //
    # pAo = poolAmountOut         /                                              \              //
    # tAi = tokenAmountIn        ///      /     //    wI \      \\       \     wI \             //
    # wI = tokenWeightIn        //| tAi *| 1 - || 1 - --  | * sF || + tBi \    --  \            //
    # tW = totalWeight     pAo=||  \      \     \\    tW /      //         | ^ tW   | * pS - pS //
    # tBi = tokenBalanceIn      \\  ------------------------------------- /        /            //
    # pS = poolSupply            \\                    tBi               /        /             //
    # sF = swapFee                \                                              /              //
    # **********************************************************************************************/
    @view
    func get_pool_minted_given_single_in{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_of_a_in : Uint256, a_balance : Uint256, supply : Uint256, a_weight : Ratio,
            total_weight : Ratio, swap_fee : Ratio) -> (pool_tokens_out : Ratio):
        alloc_locals

        # needed for dereferencing ratios
        let (__fp__, _) = get_fp_and_pc()

        let (local divide_weights : Ratio) = ratio_div(a_weight, total_weight)

        # TODO: add sanity check that 1/1 > divide_weights
        let (local step_one : Ratio) = ratio_diff(
            Ratio(Uint256(1, 0), Uint256(1, 0)), divide_weights)

        let (local step_one_times_fee : Ratio) = ratio_mul(step_one, swap_fee)

        let (local i : Uint256) = uint256_sub(step_one_times_fee.d, step_one_times_fee.n)
        local one_minus : Ratio = Ratio(i, step_one_times_fee.d)
        let (local times_amount : Ratio) = ratio_mul(
            Ratio(amount_of_a_in, Uint256(1, 0)), one_minus)
        let (local plus_token_balance : Ratio) = ratio_add(
            times_amount, Ratio(a_balance, Uint256(1, 0)))
        let (local divided_by_balance : Ratio) = ratio_div(
            plus_token_balance, Ratio(a_balance, Uint256(1, 0)))

        let (local exponent : Ratio) = ratio_div(a_weight, total_weight)

        let (local raised_to_exponent : Ratio) = ratio_pow(divided_by_balance, exponent.n)

        # nth root accurate to 9 digits
        with_attr error_message(
                "ERROR WHEN TAKING THE NTH ROOT : LIKELY FRACTION REDUCTION PROBLEM; TRY SLIGHTLY ADJUSTING NUMBERS"):
            let (local take_root_of_exponent : Ratio) = nth_root_by_digit(
                raised_to_exponent, exponent.d, 9)
        end
        let (local times_pool_supply : Ratio) = ratio_mul(
            take_root_of_exponent, Ratio(supply, Uint256(1, 0)))
        let (local amount_pool_tokens_out : Ratio) = ratio_diff(
            times_pool_supply, Ratio(supply, Uint256(1, 0)))

        return (amount_pool_tokens_out)
    end

    # IMPLEMENT LATER
    # @view
    # func get_single_in_given_pool_out{
    #        syscall_ptr : felt*,
    #        pedersen_ptr : HashBuiltin*,
    #        range_check_ptr
    #    }(erc20_address: felt, pool_amount_out: felt) -> (amount_of_a_in: felt):
    # end

    # **********************************************************************************************
    # calcSingleOutGivenPoolIn                                                                  //
    # tAo = tokenAmountOut            /      /                                             \\   //
    # bO = tokenBalanceOut           /      // pS - (pAi * (1 - eF)) \     /    1    \      \\  //
    # pAi = poolAmountIn            | bO - || ----------------------- | ^ | --------- | * b0 || //
    # ps = poolSupply                \      \\          pS           /     \(wO / tW)/      //  //
    # wI = tokenWeightIn      tAo =   \      \                                             //   //
    # tW = totalWeight                    /     /      wO \       \                             //
    # sF = swapFee                    *  | 1 - |  1 - ---- | * sF  |                            //
    # eF = exitFee                        \     \      tW /       /                             //
    # **********************************************************************************************/
    @view
    func get_single_out_given_pool_in{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_amount_in : Uint256, a_balance : Uint256, supply : Uint256, a_weight : Ratio,
            total_weight : Ratio, swap_fee : Ratio, exit_fee : Ratio) -> (amount_token_out : Ratio):
        alloc_locals

        # needed for dereferencing ratios
        let (__fp__, _) = get_fp_and_pc()

        let x : Uint256 = uint256_sub(exit_fee.d, exit_fee.n)

        # calculate main ratio
        local one_minus_exit_fee : Ratio = Ratio(x, exit_fee.d)
        let times_pool_in : Ratio = ratio_mul(
            one_minus_exit_fee, Ratio(pool_amount_in, Uint256(1, 0)))

        let (local y : Uint256, _) = uint256_mul(supply, times_pool_in.d)
        let y_adj : Uint256 = uint256_sub(y, times_pool_in.n)
        local pool_supply_minus : Ratio = Ratio(y_adj, times_pool_in.d)
        let divided_by_ps : Ratio = ratio_div(pool_supply_minus, Ratio(supply, Uint256(1, 0)))

        let exponent : Ratio = ratio_div(total_weight, a_weight)

        let raised_to_exponent : Ratio = ratio_pow(divided_by_ps, exponent.n)

        with_attr error_message(
                "ERROR WHEN TAKING THE NTH ROOT : LIKELY FRACTION REDUCTION PROBLEM; TRY SLIGHTLY ADJUSTING NUMBERS"):
            let take_root_of_exponent : Ratio = nth_root_by_digit(raised_to_exponent, exponent.d, 9)
        end

        let times_balance_out : Ratio = ratio_mul(
            take_root_of_exponent, Ratio(a_balance, Uint256(1, 0)))

        let (local z : Uint256, _) = uint256_mul(a_balance, times_balance_out.d)
        let z_adj : Uint256 = uint256_sub(z, times_balance_out.n)
        let first_ratio : Ratio = Ratio(z_adj, times_balance_out.d)

        # calculate other ratio
        let step_one : Ratio = ratio_diff(total_weight, a_weight)

        let step_one_times_fee : Ratio = ratio_mul(step_one, swap_fee)

        let k : Uint256 = uint256_sub(step_one_times_fee.d, step_one_times_fee.n)
        local second_ratio : Ratio = Ratio(k, step_one_times_fee.d)

        # multiply together
        let amount_token_out : Ratio = ratio_mul(first_ratio, second_ratio)

        return (amount_token_out)
    end

    # IMPLEMENT LATER
    # @view
    # func get_pool_in_given_single_out{
    #        syscall_ptr : felt*,
    #        pedersen_ptr : HashBuiltin*,
    #        range_check_ptr
    #    }(erc20_address: felt, amount_of_a_out: felt) -> (pool_tokens_in: felt):
    # end

    ###########################
    # SWAPS
    ###########################

    # **********************************************************************************************
    # calcOutGivenIn                                                                            //
    # aO = tokenAmountOut                                                                       //
    # bO = tokenBalanceOut                                                                      //
    # bI = tokenBalanceIn              /      /            bI             \    (wI / wO) \      //
    # aI = tokenAmountIn    aO = bO * |  1 - | --------------------------  | ^            |     //
    # wI = tokenWeightIn               \      \ ( bI + ( aI * ( 1 - sF )) /              /      //
    # wO = tokenWeightOut                                                                       //
    # sF = swapFee                                                                              //
    # **********************************************************************************************/
    @view
    func get_out_given_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_of_a_in : Uint256, a_balance : Uint256, a_weight : Ratio, b_balance : Uint256,
            b_weight : Ratio, swap_fee : Ratio) -> (amount_of_b_out : Ratio):
        alloc_locals

        # needed for dereferencing ratios
        let (__fp__, _) = get_fp_and_pc()

        local token_balance_in : Ratio = Ratio(a_balance, Uint256(1, 0))
        local token_amount_in : Ratio = Ratio(amount_of_a_in, Uint256(1, 0))
        local token_balance_out : Ratio = Ratio(b_balance, Uint256(1, 0))

        let x : Uint256 = uint256_sub(swap_fee.d, swap_fee.n)
        local one_minus_swap_fee : Ratio = Ratio(x, swap_fee.d)
        let times_tai : Ratio = ratio_mul(one_minus_swap_fee, token_amount_in)
        let plus_balance_in : Ratio = ratio_add(token_balance_in, times_tai)
        let balance_in_divided_by : Ratio = ratio_div(token_balance_in, plus_balance_in)

        let exponent : Ratio = ratio_div(a_weight, b_weight)

        let raised_to_exponent : Ratio = ratio_pow(balance_in_divided_by, exponent.n)

        with_attr error_message(
                "ERROR WHEN TAKING THE NTH ROOT : LIKELY FRACTION REDUCTION PROBLEM; TRY SLIGHTLY ADJUSTING NUMBERS"):
            let take_root_of_exponent : Ratio = nth_root_by_digit(raised_to_exponent, exponent.d, 9)
        end

        let y : Uint256 = uint256_sub(take_root_of_exponent.d, take_root_of_exponent.n)
        local one_minus_all : Ratio = Ratio(y, take_root_of_exponent.d)
        let amount_of_b_out : Ratio = ratio_mul(token_balance_out, one_minus_all)

        return (amount_of_b_out)
    end

    @view
    func get_proportional_deposits_given_pool_out{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_supply_ratio : Ratio, token_list_len : felt, token_list : TokenAndAmount*) -> (
            output_arr_len : felt, output_arr : TokenAndAmount*):
        alloc_locals

        let (local output_arr : TokenAndAmount*) = alloc()

        let (local return_arr_len : felt,
            local return_arr : TokenAndAmount*) = _recursive_get_balance_in_needed(
            pool_supply_ratio, token_list_len, token_list, 0, output_arr, 0)

        return (return_arr_len, return_arr)
    end

    func _recursive_get_balance_in_needed{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_supply_ratio : Ratio, input_arr_len : felt, input_arr : TokenAndAmount*,
            output_arr_len : felt, output_arr : TokenAndAmount*, counter : felt) -> (
            list_len : felt, list : TokenAndAmount*):
        alloc_locals

        # needed for dereferencing struct
        let (__fp__, _) = get_fp_and_pc()

        if input_arr_len == 0:
            return (output_arr_len, output_arr)
        end

        let current_struct : TokenAndAmount* = [&input_arr]
        let (local amount_in : Uint256) = _get_balance_needed_from_pool_supply(
            pool_supply_ratio, current_struct.amount)

        # assert used for assignment
        assert output_arr[counter] = TokenAndAmount(current_struct.erc_address, amount_in)

        let (local _output_arr_len : felt,
            _output_arr : TokenAndAmount*) = _recursive_get_balance_in_needed(
            pool_supply_ratio,
            input_arr_len - 1,
            input_arr + TokenAndAmount.SIZE,
            output_arr_len + 1,
            output_arr,
            counter + 1)

        return (_output_arr_len, _output_arr)
    end

    func _get_balance_needed_from_pool_supply{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_supply_ratio : Ratio, current_balance : Uint256) -> (balance_needed : Uint256):
        alloc_locals

        local ratio_current_balance : Ratio = Ratio(current_balance, Uint256(1, 0))
        let (local curr_times_supply_ratio : Ratio) = ratio_mul(
            ratio_current_balance, pool_supply_ratio)
        let (local amount_in_required : Uint256, _) = uint256_unsigned_div_rem(
            curr_times_supply_ratio.n, curr_times_supply_ratio.d)

        return (amount_in_required)
    end
end
