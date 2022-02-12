%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_mul, uint256_le, uint256_lt, uint256_signed_nn
)

##########
# STRUCTS
##########

# n -> numerator
# d -> denominator
struct Ratio:
    member n : Uint256
    member d : Uint256
end

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

    let (local n: Uint256, _) = uint256_mul(x.n, y.n)
    let (local d: Uint256, _) = uint256_mul(x.d, y.d)
    local z: Ratio = Ratio(n, d)

    return (z)
end

# divide x/y
@view
func ratio_div{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, y : Ratio) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let (local n: Uint256, _) = uint256_mul(x.n, y.d)
    let (local d: Uint256, _) = uint256_mul(x.d, y.n)

    return (Ratio(n, d))
end

# x^m where x is element of rationals and m is element of naturals -> element of rationals
@view
func ratio_pow{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : Uint256) -> (z : Ratio):
    alloc_locals

    if m.low == 0:
        return (Ratio(Uint256(1, 0), Uint256(1, 0)))
    end

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let (local y : Uint256) = uint256_sub(m, Uint256(1, 0))

    let (local rest_of_product : Ratio) = ratio_pow(x, y)
    let (local z: Ratio) = ratio_mul(x, rest_of_product)

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

# add x + y
@view
func ratio_add{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        first_ratio : Ratio, second_ratio : Ratio) -> (sum : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if first_ratio.d.low == second_ratio.d.low:
        if first_ratio.d.high == second_ratio.d.high:
            let (local a: Uint256, is_overflow) = uint256_add(first_ratio.n, second_ratio.n)
            assert (is_overflow) = 0
            local sum : Ratio = Ratio(a, first_ratio.d)
            return (sum)
        end
    end

    let (local x: Uint256, _) = uint256_mul(first_ratio.n, second_ratio.d)
    let (local y: Uint256, _) = uint256_mul(second_ratio.n, first_ratio.d)

    let (local i: Uint256, _) = uint256_add(x, y)
    let (local j: Uint256, _) = uint256_mul(first_ratio.d, second_ratio.d)
    local sum : Ratio = Ratio(
        i,
        j)
    return (sum)
end

# absolute value of base - other
@view
func ratio_diff{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        base_ratio : Ratio, other_ratio : Ratio) -> (diff : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if base_ratio.d.low == other_ratio.d.low:
        if base_ratio.d.high == other_ratio.d.high:
            let le : felt = uint256_le(other_ratio.n, base_ratio.n)
            if le == 1:
                let z: Uint256 = uint256_sub(base_ratio.n, other_ratio.n)
                let diff : Ratio = Ratio(z, base_ratio.d)
                return (diff)
            else:
                let z: Uint256 = uint256_sub(other_ratio.n, base_ratio.n)
                let diff : Ratio = Ratio(z, base_ratio.d)
                return (diff)
            end
        end
    end

    let (local x: Uint256, _) = uint256_mul(other_ratio.n, base_ratio.d)
    let (local y: Uint256, _) = uint256_mul(base_ratio.n, other_ratio.d)
    let r_le : felt = uint256_le(x, y)
    if r_le == 1:
        let (local m: Uint256, _) = uint256_mul(base_ratio.n, other_ratio.d)
        let (local n: Uint256, _) = uint256_mul(other_ratio.n, base_ratio.d)  
        let o: Uint256 = uint256_sub(m, n)
        let (local p: Uint256, _) = uint256_mul(base_ratio.d, other_ratio.d)
        let diff : Ratio = Ratio(
            o,
            p)
        return (diff)
    else:
        let (local i: Uint256, _) = uint256_mul(other_ratio.n, base_ratio.d)
        let (local j: Uint256, _) = uint256_mul(base_ratio.n, other_ratio.d)
        let k: Uint256 = uint256_sub(i, j)
        let (local l: Uint256, _) = uint256_mul(base_ratio.d, other_ratio.d)     
        let diff : Ratio = Ratio(
            k,
            l)
        return (diff)
    end
end

@view
func ratio_less_than_or_eq{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        first_ratio : Ratio, second_ratio : Ratio) -> (bool : felt):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let (local x: Uint256, _) = uint256_mul(first_ratio.n, second_ratio.d)
    let (local y: Uint256, _) = uint256_mul(second_ratio.n, first_ratio.d)
    let r_le : felt = uint256_le(x, y)
    if r_le == 1:
        return (1)
    end

    return (0)
end

# take nth root digit by digit until get to desired precision assuming 18 digits of decimals
@view
func nth_root_by_digit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : Uint256, precision : felt) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()
    
    # edge case if m == 1
    if m.low == 1:
        return (x)
    end

    # edge case if ratio is 1
    if x.n.low == x.d.low:
        if x.n.high == x.d.high:
            return (Ratio(Uint256(1, 0), Uint256(1, 0)))
        end
    end

    # calculate integer part
    local digit : felt = 0
    let (local base : felt) = pow(10, digit)
    local initial_guess : Ratio = Ratio(Uint256(1, 0), Uint256(base, 0))
    let (local integer_part_non_adjusted : Ratio) = recursive_find_integer_part(x, m, initial_guess)

    let (local z : Ratio) = find_precision_part(x, m, precision, digit, integer_part_non_adjusted)
    # let z : Ratio = Ratio(numerator.n, precision_digits)
    return (z)
end

func recursive_find_integer_part{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : Uint256, guess : Ratio) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    let (local guess_to_m : Ratio) = ratio_pow(guess, m)
    let (local le : felt) = ratio_less_than_or_eq(x, guess_to_m)

    if le == 1:
        let (local k: Uint256) = uint256_sub(guess.n, Uint256(1, 0))
        local z : Ratio = Ratio(k, Uint256(1, 0))
        return (z)
    else:
        let (local y: Uint256, is_overflow) = uint256_add(guess.n, Uint256(1, 0))
        assert (is_overflow) = 0
        local new_guess : Ratio = Ratio(y, guess.d)
        let (local z : Ratio) = recursive_find_integer_part(x, m, new_guess)
        return (z)
    end
end

func recursive_find_part{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Ratio, m : Uint256, guess : Ratio, count : felt) -> (z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    if count == 10:
        let (local y: Uint256) = uint256_sub(guess.n, Uint256(1, 0))
        return (Ratio(y, guess.d))
    end

    let (local guess_to_m : Ratio) = ratio_pow(guess, m)
    let (local le : felt) = ratio_less_than_or_eq(guess_to_m, x)
    let r_le: felt = ratio_less_than_or_eq(x, guess_to_m)

    if le == 1:
        if r_le == 1:
            return (guess)
        end

        local new_count : felt = count + 1
        let (local q: Uint256, _) = uint256_add(guess.n, Uint256(1,0))
        local new_guess : Ratio = Ratio(q, guess.d)
        let (local z : Ratio) = recursive_find_part(x, m, new_guess, new_count)
        return (z)
    else:
        let (local q: Uint256) = uint256_sub(guess.n, Uint256(1,0))
        local z : Ratio = Ratio(q, guess.d)
        return (z)
    end
end

func find_precision_part{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        current_x : Ratio, m : Uint256, precision : felt, digit : felt, current_root : Ratio) -> (
        z : Ratio):
    alloc_locals

    # needed for dereferencing ratios
    let (__fp__, _) = get_fp_and_pc()

    local current_digit : felt = digit + 1
    let (local base : felt) = pow(10, current_digit)
    let (local x: Uint256, _) = uint256_mul(current_root.n, Uint256(10, 0))
    let (local w: Uint256, _) = uint256_add(x, Uint256(1,0))
    local initial_guess : Ratio = Ratio(w, Uint256(base, 0))
    local count : felt = 1
    let (local current_part : Ratio) = recursive_find_part(current_x, m, initial_guess, count)

    let le : felt = is_le(precision, current_digit)

    if le == 1:
        return (current_part)
    else:
        let (local z : Ratio) = find_precision_part(current_x, m, precision, current_digit, current_part)
        return (z)
    end
end
