#Mammoth pool contract allowing following functionality:
#1. Deposit tokens
#2. Withdraw tokens
#3. whitelisted MM access to atomic swaps with liquidity
#4. controls on trades that can be executed
#5. view token balance
#6. view accrued return
#7. 

%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import (assert_not_zero, assert_le, unsigned_div_rem)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_unsigned_div_rem
)

#NOTE: rewards in this contract are distributed per 1000000000 wei or .000000001 ETH 

#using structs to wrap felt fo syntactic types, 
#structs will be initialized using functions with additional checks ont he type

#struct
struct Address:
    member address: felt
end

##########
#STORAGE VAR AND CONSTRUCTOR
##########

#proxy contract address
@storage_var
func _proxy() -> (res: felt):
end

#total amount deposited
@storage_var
func total_staked() -> (value: felt):
end

#amount of accrued rewards
@storage_var
func total_porportional_accrued_rewards() -> (quotient: felt):
end

#(total_value locked at time t -> total_staked + total_accrued_value)
@storage_var
func user_amount_staked(user: felt) -> (amount_staked: felt):
end

#amount of undistributed accrued rewards at time of deposit
@storage_var
func accrued_rewards_at_time_of_stake(user: felt) -> (accrued_rewards_at_time_of_stake: felt):
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    total_staked.write(0)
    total_porportional_accrued_rewards.write(0)
    ret
end

##########
#DEPOSIT, DISTRIBUTE, WITHDRAW
##########

#internal deposit FUNC
func _deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt) -> ():
    alloc_locals

    #TODO: handle case where they are already staked
    let (local staked: felt) = total_staked.read()
    let (local current_accrued_rewards: felt) = total_porportional_accrued_rewards.read()

    total_staked.write(staked + amount)
    # address -> current_accrued_rewards
    # address -> amount of eth
    accrued_rewards_at_time_of_stake.write(address, current_accrued_rewards)
    user_amount_staked.write(address, amount)

    return ()
    end


#internal distribute FUNC
#new reward calculation ->  current_balance - total_porportional_accrued_rewards
#should be run every X units of time
func _distribute{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_reward: felt) -> ():
    alloc_locals
    #rewards per 1e9 wei
    let eth_rounded_digit = 1000000000

    let (local s: felt) = total_porportional_accrued_rewards.read()
    let (local t: felt) = total_staked.read()

    #check that there is a nonzero quotient before 1e9 wei
    #one is the starting digit for recursion
    let (local digit_of_non_zero_quotient: felt) = _find_first_non_zero_quotient(new_reward, t, 1)
    assert_le(digit_of_non_zero_quotient, eth_rounded_digit)
    
    let (local quotient: felt, local remainder: felt) = unsigned_div_rem(new_reward * eth_rounded_digit, t)

    total_porportional_accrued_rewards.write(s + quotient)
    return ()
end

#internal withdraw FUNC
func _withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt):
    alloc_locals

    #TODO: handle case where they withdraw less than full amount

    let (local deposited: felt) = user_amount_staked.read(address)
    let (local s_0: felt) = accrued_rewards_at_time_of_stake.read(address)
    let (local s: felt) = total_porportional_accrued_rewards.read()

    # reward = deposited * (s - s_0)
    #TODO implement transferFrom(get_contract_address, address)

    user_amount_staked.write(address, 0)
    return ()
end

##########
#HELPERS
##########

#helper function to protect against unexpected behavior with division
#this function takes in a numerator and a denominator and outputs 10 ^ x where
#x is the digit of the first nonzero number in division
#for example, if num is 1000 and denom is 100000 then this function returns 100 or 10^2
func _find_first_non_zero_quotient{
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(numerator: felt, denominator: felt, next_digit: felt) -> (digit_of_non_zero_quotient: felt):
    alloc_locals
    let (local quotient: felt, local remainder: felt) = unsigned_div_rem(numerator, denominator)

    if quotient != 0:
        return (next_digit)
    else:
        return _find_first_non_zero_quotient(numerator * 10, denominator, next_digit * 10)
    end
end

#helper function to require call from proxy
func _require_call_from_proxy{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (local caller_address: felt) = get_caller_address()
    let (local approved_caller: felt) = _proxy.read()
    assert caller_address = approved_caller
    ret
end

##########
#EXTERNALS
##########

@external
func proxy_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt):
    call _require_call_from_proxy

    _deposit(amount, address)
    return ()
end

@external
func proxy_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt):
    call _require_call_from_proxy

    _withdraw(amount, address)
    return ()
end

@external
func proxy_distribute{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    call _require_call_from_proxy

    #alloc_locals

    #TODO: implement address template where this contract can hold eth and read current balance and read balance_at_last_snapshot
    #let (local new_reward: felt) = current_balance.read() - balance_at_last_snapshot.read()

    #_distribute(new_reward)
    return ()
end





