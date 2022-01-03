%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math import (assert_not_zero, assert_le, unsigned_div_rem)
from starkware.cairo.common.math_cmp import (is_le)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_unsigned_div_rem
    )

#n -> numerator
#d -> denominator
struct Ratio:
    member n: felt
    member d: felt
end

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

##########
# RATIOS
##########

##########
# MATH
##########

# x * y where x and y in rationals return z in rationals
@view
func ratio_mul{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, y : Ratio) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    return (Ratio(x.n * y.n, x.d * y.d))
end

# divide x/y
@view
func ratio_div{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, y : Ratio) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    return (Ratio(x.n * y.d, x.d * y.n))
end

# x^m where x is element of rationals and m is element of naturals -> element of rationals
@view
func ratio_pow{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : felt) -> (z : Ratio):
    if m == 0:
        return (Ratio(1, 1))
    end

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let rest_of_product : Ratio = ratio_pow(x, m - 1)
    let z : Ratio = ratio_mul(x, rest_of_product)

    return (z)
end

@view
func pow{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        base : felt, exponent : felt) -> (result : felt):
    if exponent == 0:
        return (1)
    end

    let rest_of_product : felt = pow(base, exponent - 1)
    let z : felt = base * rest_of_product

    return (z)
end

@view
func diff{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : felt, y : felt) -> (result : felt):
    let le : felt = is_le(y, x)
    if le == 1:
        let diff : felt = x - y
        return (diff)
    else:
        let diff : felt = y - x
        return (diff)
    end
end

# x^1/m where x = a/b with a and b in Z mod p and m in Z mod p
@view
func ratio_nth_root_binary{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : felt, error : Ratio) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    # if ratio in [0, 1]
    let le : felt = is_le(x.n, x.d)
    if le == 1:
        let low_candidate : Ratio = x
        let high_candidate : Ratio = Ratio(1, 1)

        let z : Ratio = _recursion_nth_root_binary(x, high_candidate, low_candidate, m, error)
        return (z)
        # if ratio in (1, ---]
    else:
        let low_candidate : Ratio = Ratio(1, 1)
        let high_candidate : Ratio = x

        let z : Ratio = _recursion_nth_root_binary(x, high_candidate, low_candidate, m, error)
        return (z)
    end
end

# recursion helper for nth root
func _recursion_nth_root_binary{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        base_ratio : Ratio, high_candidate : Ratio, low_candidate : Ratio, m : felt,
        error : Ratio) -> (nth_root : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let interval_sum : Ratio = ratio_add(high_candidate, low_candidate)
    let (local candidate_root : Ratio) = ratio_div(interval_sum, Ratio(2, 1))

    let less_than_error : felt = _less_than_error(base_ratio, candidate_root, m, error)

    if less_than_error == 1:
        return (candidate_root)
    else:
        let product : Ratio = ratio_pow(candidate_root, m)
        let r_le : felt = ratio_less_than_or_eq(base_ratio, product)
        if r_le == 1:
            let new_high_candidate : Ratio = candidate_root
            let result : Ratio = _recursion_nth_root_binary(
                base_ratio, new_high_candidate, low_candidate, m, error)

            return (result)
        else:
            let new_low_candidate : Ratio = candidate_root
            let result : Ratio = _recursion_nth_root_binary(
                base_ratio, high_candidate, new_low_candidate, m, error)

            return (result)
        end
    end
end

# helper function for nth root check if candidate is close enough
func _less_than_error{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        base_ratio : Ratio, candidate_root : Ratio, m : felt, error : Ratio) -> (bool : felt):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let candidate_root_raised_to_m : Ratio = ratio_pow(candidate_root, m)

    # ratio_diff is defined to check which input is larger and substract smaller from larger
    let difference : Ratio = ratio_diff(base_ratio, candidate_root_raised_to_m)

    let r_le : felt = ratio_less_than_or_eq(difference, error)
    if r_le == 1:
        return (1)
    end

    return (0)
end

# add x + y
@view
func ratio_add{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        first_ratio : Ratio, second_ratio : Ratio) -> (sum : Ratio):
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if first_ratio.d == second_ratio.d:
        let sum : Ratio = Ratio(first_ratio.n + second_ratio.n, first_ratio.d)
        return (sum)
    end

    let sum : Ratio = Ratio(
        first_ratio.n * second_ratio.d + second_ratio.n * first_ratio.d,
        first_ratio.d * second_ratio.d)
    return (sum)
end

# absolute value of base - other
@view
func ratio_diff{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        base_ratio : Ratio, other_ratio : Ratio) -> (diff : Ratio):
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if base_ratio.d == other_ratio.d:
        let le : felt = is_le(other_ratio.n, base_ratio.n)
        if le == 1:
            let diff : Ratio = Ratio(base_ratio.n - other_ratio.n, base_ratio.d)
            return (diff)
        else:
            let diff : Ratio = Ratio(other_ratio.n - base_ratio.n, base_ratio.d)
            return (diff)
        end
    end

    let r_le : felt = is_le(other_ratio.n * base_ratio.d, base_ratio.n * other_ratio.d)
    if r_le == 1:
        let diff : Ratio = Ratio(
            base_ratio.n * other_ratio.d - other_ratio.n * base_ratio.d,
            base_ratio.d * other_ratio.d)
        return (diff)
    else:
        let diff : Ratio = Ratio(
            other_ratio.n * base_ratio.d - base_ratio.n * other_ratio.d,
            base_ratio.d * other_ratio.d)
        return (diff)
    end
end

@view
func ratio_less_than_or_eq{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        first_ratio : Ratio, second_ratio : Ratio) -> (bool : felt):
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let r_le : felt = is_le(first_ratio.n * second_ratio.d, second_ratio.n * first_ratio.d)
    if r_le == 1:
        return (1)
    end

    return (0)
end

# take nth root digit by digit until get to desired precision assuming 18 digits of decimals
@view
func nth_root_by_digit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : felt, precision : felt) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    # edge case if m == 1
    if m == 1:
        return (x)
    end

    # edge case if ratio is 1
    if x.n == x.d:
        return (Ratio(1, 1))
    end

    # calculate integer part
    let digit : felt = 0
    let base : felt = pow(10, digit)
    let initial_guess : Ratio = Ratio(1, base)
    let (local integer_part_non_adjusted : Ratio) = recursive_find_integer_part(x, m, initial_guess)

    let z : Ratio = find_precision_part(x, m, precision, digit, integer_part_non_adjusted)
    # let z : Ratio = Ratio(numerator.n, precision_digits)
    return (z)
end

@view
func recursive_find_integer_part{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : felt, guess : Ratio) -> (z : Ratio):
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let guess_to_m : Ratio = ratio_pow(guess, m)
    let le : felt = ratio_less_than_or_eq(x, guess_to_m)

    if le == 1:
        let z : Ratio = Ratio(guess.n - 1, 1)
        return (z)
    else:
        let new_guess : Ratio = Ratio(guess.n + 1, 1)
        let z : Ratio = recursive_find_integer_part(x, m, new_guess)
        return (z)
    end
end

@view
func recursive_find_part{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : felt, guess : Ratio, count : felt) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if count == 10:
        return (Ratio(guess.n - 1, guess.d))
    end

    let (local guess_to_m : Ratio) = ratio_pow(guess, m)
    let le : felt = ratio_less_than_or_eq(guess_to_m, x)
    let r_le: felt = ratio_less_than_or_eq(x, guess_to_m)

    if le == 1:
        if r_le == 1:
            return (guess)
        end

        let new_count : felt = count + 1
        let new_guess : Ratio = Ratio(guess.n + 1, guess.d)
        let z : Ratio = recursive_find_part(x, m, new_guess, new_count)
        return (z)
    else:
        let z : Ratio = Ratio(guess.n - 1, guess.d)
        return (z)
    end
end

@view
func find_precision_part{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        current_x : Ratio, m : felt, precision : felt, digit : felt, current_root : Ratio) -> (
        z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let current_digit : felt = digit + 1
    let base : felt = pow(10, current_digit)
    let initial_guess : Ratio = Ratio(current_root.n * 10 + 1, base)
    let count : felt = 1
    let (local current_part : Ratio) = recursive_find_part(current_x, m, initial_guess, count)

    let le : felt = is_le(precision, current_digit)

    if le == 1:
        return (current_part)
    else:
        let z : Ratio = find_precision_part(current_x, m, precision, current_digit, current_part)
        return (z)
    end
end
