%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256

from contracts.lib.fixed_point.src.fixed_point import FixedPoint
from contracts.config import ONE

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
    #   a_balance/a_weight          1
    #           /               *           /
    #   b_balance/b_weight          1 - swap_fee
    #
    @view
    func get_spot_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            a_balance : Uint256, a_weight : Uint256, b_balance : Uint256, b_weight : Uint256,
            fee : Uint256) -> (spot_price : Uint256):
        alloc_locals

        let (local x : Uint256) = FixedPoint.div(a_balance, a_weight)
        let (local y : Uint256) = FixedPoint.div(b_balance, b_weight)
        let fee_adj : Uint256 = FixedPoint.sub(ONE, swap_fee)

        let (local balance_ratio : Uint256) = FixedPoint.div(x, y)
        let (local fee_ratio : Uint256) = FixedPoint.div(ONE, fee_adj)

        let (local spot_price : Uint256) = FixedPoint.mul(balance_ratio, fee_ratio)

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

        let (local divide_weights : Uint256) = FixedPoint.div(a_weight, total_weight)

        let (local step_one : Uint256) = FixedPoint.sub(ONE, divide_weights)
        let (local step_one_times_fee : Uint256) = FixedPoint.mul(step_one, swap_fee)
        let (local one_minus : Uint256) = FixedPoint.sub(ONE, step_one_times_fee)
        let (local times_amount_in : Uint256) = FixedPoint.mul(amount_of_a_in, one_minus)
        let (local plus_token_balance : Uint256) = FixedPoint.add(times_amount_in, a_balance)
        let (local divided_by_balance : Uint256) = FixedPoint.div(plus_balance_in, a_balance)
        let (local raised_to_weight_ratio : Uint256) = FixedPoint.bounded_pow(
            divided_by_balance, divide_weights)
        let (local times_pool_supply : Uint256) = FixedPoint.mul(raised_to_weight_ratio, supply)
        let (local amount_pool_tokens_out : Uint256) = FixedPoint.sub(times_pool_supply, supply)

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
            pool_amount_in : Uint256, a_balance : Uint256, supply : Uint256, a_weight : Uint256,
            total_weight : Uint256, swap_fee : Uint256, exit_fee : Uint256) -> (
            amount_token_out : Ratio):
        alloc_locals

        let (local one_minus_exit_fee : Uint256) = FixedPoint.sub(ONE, exit_fee)
        let (local pool_amount_in_after_exit_fee : Uint256) = FixedPoint.mul(
            pool_amount_in, one_minus_exit_fee)
        let (local new_pool_supply : Uint256) = FixedPoint.sub(
            supply, pool_amount_in_after_exit_fee)
        let (local new_pool_div_old_pool : Uint256) = FixedPoint.div(pool_supply_minus, supply)

        let (local weight_ratio : Uint256) = FixedPoint.div(a_weight, total_weight)
        let (local exponent : Uint256) = FixedPoint.div(ONE, weight_ratio)
        let (local token_out_ratio : Uint256) = FixedPoint.bounded_pow(
            new_pool_div_old_pool, exponent)

        let (local new_token_balance : Uint256) = FixedPoint.mul(token_out_ratio, a_balance)
        let (local token_amount_out_before_swap_fee : Uint256) = FixedPoint.sub(
            a_balance, new_token_balance)

        # swap fee
        let (local one_minus_weight_ratio : Uint256) = FixedPoint.sub(ONE, weight_ratio)
        let (local multiply_by_swap_fee : Uint256) = FixedPoint.mul(
            one_minus_weight_ratio, swap_fee)
        let (local one_minus_all : Uint256) = FixedPoint.sub(ONE, multiply_by_swap_fee)

        # final multiplication
        let (local token_amount_out : Uint256) = FixedPoint.mul(
            token_amount_out_before_swap_fee, one_minus_all)

        return (token_amount_out)
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
            amount_of_a_in : Uint256, a_balance : Uint256, a_weight : Uint256, b_balance : Uint256,
            b_weight : Uint256, swap_fee : Uint256) -> (amount_of_b_out : Uint256):
        alloc_locals

        # needed for dereferencing ratios
        let (__fp__, _) = get_fp_and_pc()

        let (local weight_ratio : Uint256) = FixedPoint.div(a_weight, b_weight)
        let (local one_minus_swap_fee : Uint256) = FixedPoint.sub(ONE, swap_fee)
        let (local adjusted_in : Uint256) = FixedPoint.mul(amount_of_a_in, one_minus_swap_fee)

        let (local new_balance_in : Uint256) = FixedPoint.add(a_balance, adjusted_in)
        let (local balance_in_ratio : Uint256) = FixedPoint.div(a_balance, new_balance_in)
        let (local impact_on_balance_out : Uint256) = FixedPoint.bounded_pow(
            balance_in_ratio, weight_ratio)
        let (local out_balance_multiplier : Uint256) = FixedPoint.sub(ONE, impact_on_balance_out)
        let (local token_amount_out : Uint256) = FixedPoint.mul(b_balance, out_balance_multiplier)

        return (token_amount_out)
    end

    @view
    func get_proportional_withdraw_given_pool_in{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_total_supply : Uint256, pool_amount_in : Uint256, exit_fee : Ratio,
            token_list_len : felt, token_list : TokenAndAmount*) -> (
            output_arr_len : felt, output_arr : TokenAndAmount*):
        alloc_locals

        local ratio_in : Ratio = Ratio(pool_amount_in, Uint256(1, 0))
        let (local fee_adj : Ratio) = ratio_mul(ratio_in, exit_fee)
        let (local adj_in : Ratio) = ratio_diff(ratio_in, fee_adj)
        local ratio_total_supply : Ratio = Ratio(pool_total_supply, Uint256(1, 0))
        let (local adj_pool_supply_ratio : Ratio) = ratio_div(adj_in, ratio_total_supply)

        let (local output_arr : TokenAndAmount*) = alloc()

        let (local return_arr_len : felt,
            local return_arr : TokenAndAmount*) = _recursive_get_balance_needed(
            adj_pool_supply_ratio, token_list_len, token_list, 0, output_arr, 0)

        return (return_arr_len, return_arr)
    end

    @view
    func get_proportional_deposits_given_pool_out{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_supply_ratio : Ratio, token_list_len : felt, token_list : TokenAndAmount*) -> (
            output_arr_len : felt, output_arr : TokenAndAmount*):
        alloc_locals

        let (local output_arr : TokenAndAmount*) = alloc()

        let (local return_arr_len : felt,
            local return_arr : TokenAndAmount*) = _recursive_get_balance_needed(
            pool_supply_ratio, token_list_len, token_list, 0, output_arr, 0)

        return (return_arr_len, return_arr)
    end

    func _recursive_get_balance_needed{
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
            _output_arr : TokenAndAmount*) = _recursive_get_balance_needed(
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
        let (local amount_required : Uint256, _) = uint256_unsigned_div_rem(
            curr_times_supply_ratio.n, curr_times_supply_ratio.d)

        return (amount_required)
    end
end
