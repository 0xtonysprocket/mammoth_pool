%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import (assert_not_zero, assert_le, unsigned_div_rem)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_unsigned_div_rem

#total amount deposited of a given erc20
@storage_var
func total_staked(erc20_address: felt) -> (value: felt):
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

#total supply of pool tokens
@storage_var
func pool_token_supply() -> (supply: felt)
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
    }(  token_a: felt, 
        token_b: felt) -> (spot_price: Ratio):
    alloc_locals

    local a_balance: felt) = total_staked.read(token_a)
    local a_weight: Ratio) = token_weight.read(token_a)
    local b_balance: felt) = total_staked.read(token_b)
    local b_weight: Ratio) = token_weight.read(token_b)
    local fee: Ratio) = swap_fee.read()

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let (local num_n: felt, local num_d: felt) = (n=a_balance * a_weight.n, d=a_weight.d)
    let (local den_n: felt, local den_d: felt) = (n=b_balance * b_weight.n, d=b_weight.d)

    let (spot_price: Ratio) = Ratio(n=num_n * den_d  * fee.d, d=den_n * num_d * (fee.d - fee.n))

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
    }(  erc20_address: felt, 
        amount_of_a_in: felt,
        a_balance: felt,
        supply: felt,
        a_weight: Ratio,
        total_weight: Ratio,
        swap_fee: Ratio) -> (pool_tokens_out: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    # always positive if weights are normalized
    local (step_one: Ratio) = ratio_diff(total_weight, a_weight)
    
    local (step_one_times_fee: Ratio) = ratio_mul(step_one, fee)
    local (one_minus: Ratio) = (step_one_times_fee.d - step_one_times_fee.n, step_one_times_fee.d)
    local (times_amount: Ratio) = ratio_mul(Ratio(amount_of_a_in, 1), one_minus)
    local (plus_token_balance: Ratio) = ratio_add(times_amount, Ratio(a_balance, 1))
    local (divided_by_balance: Ratio) = ratio_div(plus_token_balance, Ratio(a_balance, 1))
    
    local (exponent: Ratio) = ratio_div(a_weight, total_weight)

    local (raised_to_exponent: Ratio) = ratio_pow(divided_by_balance, exponent.n)
    local (take_root_of_exponent: Ratio) = ratio_nth_root(raised_to_exponent, exponent.d)
    local (times_pool_supply: Ratio) = ratio_mul(take_root_of_exponent, Ratio(supply, 1))
    local (amount_pool_tokens_out: Ratio) = Ratio(times_pool_supply.n - supply * times_pool_supply.d, times_pool_supply.d)

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
    }(  erc20_address: felt, 
        pool_amount_in: felt,
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
    local (one_minus_exit_fee: Ratio) = Ratio(exit_fee.d - exit_fee.n, exit_fee.d)
    local (times_pool_in: Ratio) = ratio_mul(one_minus_exit_fee, Ratio(pool_amount_in, 1))
    local (pool_supply_minus: Ratio) = Ratio(supply * times_pool_in.d - times_pool_in.n, times_pool_in.d)
    local (divided_by_ps: Ratio) = ratio_div(pool_supply_minus, Ratio(supply, 1))

    local (exponent: Ratio) = ratio_div(total_weight, a_weight)

    local (raised_to_exponent: Ratio) = ratio_pow(divided_by_ps, exponent.n)
    local (take_root_of_exponent: Ratio) = ratio_nth_root(raised_to_exponent, exponent.d)
    local (times_balance_out: Ratio) = ratio_mul(take_root_of_exponent, Ratio(a_balance, 1))
    local (first_ratio: Ratio) = Ratio(a_balance * times_balance_out.d - times_balance_out.n, times_balance_out.d)

    #calculate other ratio
    local (step_one: Ratio) = ratio_diff(total_weight, a_weight)
    
    local (step_one_times_fee: Ratio) = ratio_mul(step_one, fee)
    local (second_ratio: Ratio) = (step_one_times_fee.d - step_one_times_fee.n, step_one_times_fee.d)

    #multiply together
    local (amount_token_out: Ratio) = ratio_mul(first_ratio, second_ratio)

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
    }(  erc20_address: felt, 
        amount_of_a_in: felt,
        a_balance: felt,
        a_weight: Ratio,
        b_balance: felt,
        b_weight: Ratio,
        swap_fee: Ratio) -> (amount_of_b_out: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    local (token_balance_in: Ratio) = Ratio(a_balance, 1)
    local (token_amount_in: Ratio) = Ratio(amount_of_a_in, 1)
    local (token_balance_out: Ratio) = Ratio(b_balance, 1)

    local (one_minus_swap_fee: Ratio) = (swap_fee.d - swap_fee.n, swap_fee.d)
    local (times_tai: Ratio) = ratio_mul(one_minus_swap_fee, token_amount_in)
    local (plus_balance_in: Ratio) = ratio_add(token_balance_in, times_tai)
    local (balance_in_divided_by: Ratio) = ratio_div(token_balance_in, plus_balance_in)

    local (exponent: Ratio) = ratio_div(a_weight, b_weight)

    local (raised_to_exponent: Ratio) = ratio_pow(balance_in_divided_by, exponent.n)
    local (take_root_of_exponent: Ratio) = ratio_nth_root(raised_to_exponent, exponent.d)

    local (one_minus_all: Ratio) = (take_root_of_exponent.d - take_root_of_exponent.n, take_root_of_exponent.d)
    local (amount_of_b_out: Ratio) = ratio_mul(token_balance_out, one_minus_all)

    return (amount_of_b_out)
end

##########
# RATIOS
##########

#n -> numerator
#d -> denominator
struct Ratio:
    member n: felt
    member d: felt
end

##########
# MATH
##########

#x * y where x and y in rationals return z in rationals
@view
func ratio_mul{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(x: Ratio, y: Ratio) -> (z: Ratio):
    alloc_locals
    
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    return (Ratio(x.n * y.n, x.d * y.d))
end

#divide x/y
@view
func ratio_div{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(x: Ratio, y: Ratio) -> (z: Ratio):
    alloc_locals
    
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    return (Ratio(x.n * y.d, x.d * y.n))
end

#x^m where x is element of rationals and m is element of naturals -> element of rationals
func ratio_pow{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(x: Ratio, m: felt) -> (z: Ratio):
    alloc_locals

    if m == 0:
        return (Ratio(1, 1))
    end

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let rest_of_product: Ratio = ratio_pow(x, m - 1)
    let z: Ratio = ratio_mul(x, rest_of_product)

    return (z)
end

#x^1/m where x = a/b with a and b in Z mod p and m in Z mod p
@view
func ratio_nth_root{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(x: Ratio, m: felt, error: Ratio) -> (z: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    # if ratio in [0, 1]
    let le: felt = is_le(x.n, x.d)
    if le == 1:
        let low_candidate: Ratio = x
        let high_candidate: Ratio = Ratio(1, 1)

        let z: Ratio = _recursion_nth_root(x, high_candidate, low_candidate, m, error)
        return (z)
    # if ratio in (1, ---]
    else:
        let low_candidate: Ratio = Ratio(1, 1)
        let high_candidate: Ratio = x

        let z: Ratio = _recursion_nth_root(x, high_candidate, low_candidate, m, error)
        return (z)
    end
end

#recursion helper for nth root
func _recursion_nth_root{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(base_ratio: Ratio, high_candidate: Ratio, low_candidate: Ratio, m: felt, error: Ratio) -> (nth_root: Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let interval_sum: Ratio = ratio_add(high_candidate, low_candidate)
    let (local candidate_root: Ratio) = ratio_div(interval_sum, Ratio(2,1))

    let less_than_error: felt = _less_than_error(base_ratio, candidate_root, m, error)

    if less_than_error == 1:
        return (candidate_root)
    else:
        let product: Ratio = ratio_pow(candidate_root, m)
        let r_le: felt = ratio_less_than_or_eq(base_ratio, product)
        if r_le == 1:
            let new_high_candidate: Ratio = candidate_root
            let result: Ratio = _recursion_nth_root(base_ratio, new_high_candidate, low_candidate, m, error)

            return (result)
        else:
            let new_low_candidate: Ratio = candidate_root
            let result: Ratio = _recursion_nth_root(base_ratio, high_candidate, new_low_candidate, m, error)

            return (result)
        end
    end
end

# helper function for nth root check if candidate is close enough
func _less_than_error{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(base_ratio: Ratio, candidate_root: Ratio, m: felt, error: Ratio) -> (bool: felt):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let candidate_root_raised_to_m: Ratio = ratio_pow(candidate_root, m)
    
    #ratio_diff is defined to check which input is larger and substract smaller from larger
    let difference: Ratio = ratio_diff(base_ratio, candidate_root_raised_to_m)

    let r_le: felt = ratio_less_than_or_eq(difference, error)
    if r_le == 1:
        return (1)
    end

    return (0)
end

# add x + y
@view
func ratio_add{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(first_ratio: Ratio, second_ratio: Ratio) -> (sum: Ratio):
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if first_ratio.d == second_ratio.d:
        let sum: Ratio = Ratio(first_ratio.n + second_ratio.n, first_ratio.d)
        return (sum)
    end

    let sum: Ratio = Ratio(first_ratio.n * second_ratio.d + second_ratio.n * first_ratio.d, first_ratio.d * second_ratio.d)
    return (sum)
end

#absolute value of base - other
@view
func ratio_diff{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(base_ratio: Ratio, other_ratio: Ratio) -> (diff: Ratio):
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if base_ratio.d == other_ratio.d:
        let le: felt = is_le(other_ratio.n, base_ratio.n)
        if le == 1:
            let diff: Ratio = Ratio(base_ratio.n - other_ratio.n, base_ratio.d)
            return (diff)
        else:
            let diff: Ratio = Ratio(other_ratio.n - base_ratio.n, base_ratio.d)
            return (diff)
        end
    end

    let r_le: felt = is_le(other_ratio.n * base_ratio.d, base_ratio.n * other_ratio.d)
    if r_le == 1:
        let diff: Ratio = Ratio(base_ratio.n * other_ratio.d - other_ratio.n * base_ratio.d, base_ratio.d * other_ratio.d)
        return (diff)
    else:
        let diff: Ratio = Ratio(other_ratio.n * base_ratio.d - base_ratio.n * other_ratio.d, base_ratio.d * other_ratio.d)
        return (diff)
    end
end

@view
func ratio_less_than_or_eq{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(first_ratio: Ratio, second_ratio: Ratio) -> (bool: felt):
    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let r_le: felt = is_le(first_ratio.n * second_ratio.d, second_ratio.n * first_ratio.d)
    if r_le == 1:
        return (1)
    end

    return (0)
end