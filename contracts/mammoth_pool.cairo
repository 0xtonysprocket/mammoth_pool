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
from starkware.cairo.common.math import (assert_not_zero, assert_le)
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

#proxy contract address
@storage_var
func _proxy() -> (res: ProxyAddress):
end

#total amount deposited
@storage_var
func total_staked() -> (value: Uint256):
end

#amount of accrued rewards
@storage_var
func total_porportional_accrued_rewards() -> (quotient: Uint256)
end

#(total_value locked at time t -> total_staked + total_accrued_value)
@storage_var
func user_amount_staked(user: felt) -> (amount_staked: Uint256)
end

#amount of undistributed accrued rewards at time of deposit
@storage_var
func accrued_rewards_at_time_of_stake(user: felt) -> (accrued_rewards_at_time_of_stake: Uint256)
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    total_staked.write(0)
    total_porportional_accrued_rewards.write(0)
end


#internal deposit FUNC
func _deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt) -> ():
    alloc_locals

    #TODO: handle case where they are already staked
    let (local new_total) = total_staked.read() + ammount
    let (local current_accrued_rewards) = total_porportional_accrued_rewards.read()

    total_staked.write(new_total)
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
    }(new_reward: Uint256) -> ():
    alloc_locals
    #rewards per 1e9 wei
    let eth_rounded_digit = 1000000000

    let (local s) = total_porportional_accrued_rewards.read()
    let (local t) = total_staked.read()

    #check that there is a nonzero quotient before 1e9 wei
    let (local digit_of_non_zero_quotient) = _find_first_non_zero_quotient(new_reward, t)
    assert_le(digit_of_non_zero_quotient, eth_rounded_digit)
    
    let (local new_reward_e9) = new_reward * eth_rounded_digit
    let (local (quotient, remainder)) = uint256_unsigned_div_rem(new_reward_e9, t)
    let (local new_porportional_award) = s + quotient

    total_porportional_accrued_rewards.write(new_porportional_award)
    return ()
end

#internal withdraw FUNC
func _withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt):
    alloc_locals

    let (local deposited) = user_amount_staked.read(address)
    let (local s_0) = accrued_rewards_at_time_of_stake.read(address)
    let (local s) = total_porportional_accrued_rewards.read()

    let (local reward) = deposit * (s - s_0)
    #TODO implement transferFrom(get_contract_address, address)

    user_amount_staked.write(0)
    return ()
end

#helper function to protect against unexpected behavior with division
func _find_first_non_zero_quotient{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(numerator: Uint256, denominator: Uint256) -> (digit_of_non_zero_quotient: Uint256):
    alloc_locals

    let (local x) = 1
    let (local num) = x * numerator
    let (local (quotient, remainder)) = uint256_unsigned_div_rem(num, denominator)

    jmp done if quotient != 0

    quotient_is_0:
    x = x * 10
    num = x * num
    (quotient, remainder) = uint256_unsigned_div_rem(num, denominator)
    jmp done if quotient != 0
    jmp quotient_is_0

    done:
    [ap] = x; ap++
    ret
end

#helper function to require call from proxy
func _require_call_from_proxy{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (caller) = call get_caller_address
    assert caller = _proxy.read()
end

#EXTERNALS

@external
func proxy_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt):
    call _require_call_from_proxy

    _deposit(amount, address)
    return ()
end

@external
func proxy_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt):
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

    alloc_locals

    #TODO: implement address template where this contract can hold eth and read current balance and read balance_at_last_snapshot
    let (local new_reward: Uint256) = current_balance.read() - balance_at_last_snapshot.read()

    _distribute(new_reward)
    return ()
end





