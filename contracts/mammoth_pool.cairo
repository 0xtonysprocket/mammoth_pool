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
func total_accrued_rewards() -> (value: felt)
end

#(total_value locked at time t -> total_staked + total_accrued_value)
@storage_var
func user_amount_staked(user: felt) -> (amount_staked: felt)
end

#amount of undistributed accrued rewards at time of deposit
@storage_var
func accrued_rewards_at_time_of_stake(user: felt) -> (rewards_at_time_of_stake: felt)
end


