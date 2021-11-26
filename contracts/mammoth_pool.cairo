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
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

#using structs to wrap felt fo syntactic types, 
#structs will be initialized using functions with additional checks ont he type

#struct
struct Address:
    member address: felt
end

#total amount deposited
@storage_var
func total_staked() -> (value: felt):
end

#amount of accrued rewards
@storage_var
func total_porportional_accrued_rewards() -> (value: felt)
end

#(total_value locked at time t -> total_staked + total_accrued_value)
@storage_var
func user_amount_staked(user: felt) -> (amount_staked: felt)
end

#amount of undistributed accrued rewards at time of deposit
@storage_var
func accrued_rewards_at_time_of_stake(user: felt) -> (rewards_at_time_of_stake: felt)
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    total_staked.write(0)
    total_porportional_accrued_rewards.write(0)
end


#internal deposit FUNC
func _deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_of_eth: felt) -> ( 

#TODO: handle case where they are already staked
#Increase total_staked by amount
#set accrued_rewards_at_time_of_stake[user] = total_porportional_accrued_rewards
#set user_amount_staked[user] = amount


#internal distribute FUNC
#input: new reward

#total_porportional_accrued_rewards = total_porportional_accrued_rewards + new_reward/total_staked

#internal withdraw FUNC
#input:amount to withdraw

#deposited = user_amount_staked[user]
#reward = deposited * (total_porportional_accrued_rewards - accrued_rewards_at_time_of_stake[user])





