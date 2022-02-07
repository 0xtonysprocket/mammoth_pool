%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_not_zero, assert_le, unsigned_div_rem

##########
# STRUCTS
##########

# n -> numerator
# d -> denominator
struct Ratio:
    member n : felt
    member d : felt
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
