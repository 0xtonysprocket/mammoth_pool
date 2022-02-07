%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math import (assert_not_zero, assert_le, unsigned_div_rem)
from starkware.cairo.common.math_cmp import (is_le)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_unsigned_div_rem
    )

from lib.local_cairo.ratio import (Ratio, ratio_mul, ratio_div, ratio_add, ratio_diff, nth_root_by_digit, pow, ratio_pow, ratio_less_than_or_eq)

#########
# BALANCER STYLE MATH
# CONSTANT VALUE INVARIANT
#########

#Cairo implementation of https://github.com/balancer-labs/balancer-core/blob/master/contracts/BMath.sol

#
#   a_balance/a_weight          fee.denominator
#           /               *           /
#   b_balance/b_weight          fee.denominator - fee.numerator
#
@view
func get_spot_price{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(  a_balance: felt,
        a_weight: Ratio,
        b_balance: felt,
        b_weight: Ratio,
        fee: Ratio)  -> (spot_price: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    local num_ratio: Ratio = Ratio(n=a_balance * a_weight.n, d=a_weight.d)
    local den_ratio: Ratio = Ratio(n=b_balance * b_weight.n, d=b_weight.d)
    local spot_price: Ratio = Ratio(n=num_ratio.n * den_ratio.d  * fee.d, d=den_ratio.n * num_ratio.d * (fee.d - fee.n))

    #sanity
    assert_not_zero(spot_price.n)
    assert_not_zero(spot_price.d)

    return (spot_price)
end

###########################
# DEPOSITS AND WITHDRAWALS
###########################

#**********************************************************************************************
#calcPoolOutGivenSingleIn                                                                  //
#pAo = poolAmountOut         /                                              \              //
#tAi = tokenAmountIn        ///      /     //    wI \      \\       \     wI \             //
#wI = tokenWeightIn        //| tAi *| 1 - || 1 - --  | * sF || + tBi \    --  \            //
#tW = totalWeight     pAo=||  \      \     \\    tW /      //         | ^ tW   | * pS - pS //
#tBi = tokenBalanceIn      \\  ------------------------------------- /        /            //
#pS = poolSupply            \\                    tBi               /        /             //
#sF = swapFee                \                                              /              //
#**********************************************************************************************/
@view
func get_pool_minted_given_single_in{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(  amount_of_a_in: felt,
        a_balance: felt,
        supply: felt,
        a_weight: Ratio,
        total_weight: Ratio,
        swap_fee: Ratio) -> (pool_tokens_out: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let divide_weights: Ratio = ratio_div(a_weight, total_weight)

    #TODO: add sanity check that 1/1 > divide_weights
    let step_one: Ratio = ratio_diff(Ratio(1, 1), divide_weights)
    
    let step_one_times_fee: Ratio = ratio_mul(step_one, swap_fee)
    local one_minus: Ratio = Ratio(step_one_times_fee.d - step_one_times_fee.n, step_one_times_fee.d)
    let times_amount: Ratio = ratio_mul(Ratio(amount_of_a_in, 1), one_minus)
    let plus_token_balance: Ratio = ratio_add(times_amount, Ratio(a_balance, 1))
    let divided_by_balance: Ratio = ratio_div(plus_token_balance, Ratio(a_balance, 1))
    
    let exponent: Ratio = ratio_div(a_weight, total_weight)

    let raised_to_exponent: Ratio = ratio_pow(divided_by_balance, exponent.n)

    #nth root accurate to 9 digits
    let take_root_of_exponent: Ratio = nth_root_by_digit(raised_to_exponent, exponent.d, 9)
    let times_pool_supply: Ratio = ratio_mul(take_root_of_exponent, Ratio(supply, 1))
    let amount_pool_tokens_out: Ratio = ratio_diff(times_pool_supply, Ratio(supply, 1))

    return (amount_pool_tokens_out)
end

#IMPLEMENT LATER
#@view
#func get_single_in_given_pool_out{
#        syscall_ptr : felt*,
#        pedersen_ptr : HashBuiltin*,
#        range_check_ptr
#    }(erc20_address: felt, pool_amount_out: felt) -> (amount_of_a_in: felt):
#end


#**********************************************************************************************
#calcSingleOutGivenPoolIn                                                                  //
#tAo = tokenAmountOut            /      /                                             \\   //
#bO = tokenBalanceOut           /      // pS - (pAi * (1 - eF)) \     /    1    \      \\  //
#pAi = poolAmountIn            | bO - || ----------------------- | ^ | --------- | * b0 || //
#ps = poolSupply                \      \\          pS           /     \(wO / tW)/      //  //
#wI = tokenWeightIn      tAo =   \      \                                             //   //
#tW = totalWeight                    /     /      wO \       \                             //
#sF = swapFee                    *  | 1 - |  1 - ---- | * sF  |                            //
#eF = exitFee                        \     \      tW /       /                             //
#**********************************************************************************************/

@view
func get_single_out_given_pool_in{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(  pool_amount_in: felt,
        a_balance: felt,
        supply: felt,
        a_weight: Ratio,
        total_weight: Ratio,
        swap_fee: Ratio,
        exit_fee: Ratio) -> (amount_token_out: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    #calculate main ratio
    local one_minus_exit_fee: Ratio = Ratio(exit_fee.d - exit_fee.n, exit_fee.d)
    let times_pool_in: Ratio = ratio_mul(one_minus_exit_fee, Ratio(pool_amount_in, 1))
    local pool_supply_minus: Ratio = Ratio(supply * times_pool_in.d - times_pool_in.n, times_pool_in.d)
    let divided_by_ps: Ratio = ratio_div(pool_supply_minus, Ratio(supply, 1))

    let exponent: Ratio = ratio_div(total_weight, a_weight)

    let raised_to_exponent: Ratio = ratio_pow(divided_by_ps, exponent.n)
    let take_root_of_exponent: Ratio = nth_root_by_digit(raised_to_exponent, exponent.d, 9)
    let times_balance_out: Ratio = ratio_mul(take_root_of_exponent, Ratio(a_balance, 1))
    let first_ratio: Ratio = Ratio(a_balance * times_balance_out.d - times_balance_out.n, times_balance_out.d)

    #calculate other ratio
    let step_one: Ratio = ratio_diff(total_weight, a_weight)
    
    let step_one_times_fee: Ratio = ratio_mul(step_one, swap_fee)
    local second_ratio: Ratio = Ratio(step_one_times_fee.d - step_one_times_fee.n, step_one_times_fee.d)

    #multiply together
    let amount_token_out: Ratio = ratio_mul(first_ratio, second_ratio)

    return (amount_token_out)
end

#IMPLEMENT LATER
#@view
#func get_pool_in_given_single_out{
#        syscall_ptr : felt*,
#        pedersen_ptr : HashBuiltin*,
#        range_check_ptr
#    }(erc20_address: felt, amount_of_a_out: felt) -> (pool_tokens_in: felt):
#end

###########################
# SWAPS
###########################

#**********************************************************************************************
#calcOutGivenIn                                                                            //
#aO = tokenAmountOut                                                                       //
#bO = tokenBalanceOut                                                                      //
#bI = tokenBalanceIn              /      /            bI             \    (wI / wO) \      //
#aI = tokenAmountIn    aO = bO * |  1 - | --------------------------  | ^            |     //
#wI = tokenWeightIn               \      \ ( bI + ( aI * ( 1 - sF )) /              /      //
#wO = tokenWeightOut                                                                       //
#sF = swapFee                                                                              //
#**********************************************************************************************/

@view
func get_out_given_in{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(  amount_of_a_in: felt,
        a_balance: felt,
        a_weight: Ratio,
        b_balance: felt,
        b_weight: Ratio,
        swap_fee: Ratio) -> (amount_of_b_out: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    local token_balance_in: Ratio = Ratio(a_balance, 1)
    local token_amount_in: Ratio = Ratio(amount_of_a_in, 1)
    local token_balance_out: Ratio = Ratio(b_balance, 1)

    local one_minus_swap_fee: Ratio = Ratio(swap_fee.d - swap_fee.n, swap_fee.d)
    let times_tai: Ratio = ratio_mul(one_minus_swap_fee, token_amount_in)
    let plus_balance_in: Ratio = ratio_add(token_balance_in, times_tai)
    let balance_in_divided_by: Ratio = ratio_div(token_balance_in, plus_balance_in)

    let exponent: Ratio = ratio_div(a_weight, b_weight)

    let raised_to_exponent: Ratio = ratio_pow(balance_in_divided_by, exponent.n)
    let take_root_of_exponent: Ratio = nth_root_by_digit(raised_to_exponent, exponent.d, 9)

    local one_minus_all: Ratio = Ratio(take_root_of_exponent.d - take_root_of_exponent.n, take_root_of_exponent.d)
    let amount_of_b_out: Ratio = ratio_mul(token_balance_out, one_minus_all)

    return (amount_of_b_out)
end