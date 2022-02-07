#Mammoth pool contract allowing following functionality:
#1. Deposit tokens
#2. Withdraw tokens
#3. whitelisted MM access to atomic swaps with liquidity
#4. controls on trades that can be executed
#5. view token balance
#6. view accrued return
#7. 

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import (assert_not_zero, assert_le, unsigned_div_rem)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_unsigned_div_rem
)

from lib.local_cairo.ratio import Ratio

#NOTE: rewards in this contract are distributed per 1000000000 wei or .000000001 ETH 

##########
#INTERFACES
##########

@contract_interface
namespace IERC20:
    func get_total_supply() -> (res: felt):
    end

    func get_decimals() -> (res: felt):
    end

    func balanceOf(account: felt) -> (res: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (res: felt):
    end

    func transfer(recipient: felt, amount: Uint256):
    end

    func transferFrom(sender: felt, recipient: felt, amount: Uint256):
    end

    func approve(spender: felt, amount: felt):
    end
end

##########
#STORAGE VAR AND CONSTRUCTOR
##########

#proxy contract address
@storage_var
func _proxy() -> (res: felt):
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(proxy: felt):
    _proxy.write(proxy)
    return ()
end

##########
#DEPOSIT, DISTRIBUTE, WITHDRAW
##########

#internal deposit FUNC
func _deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt) -> ():
    alloc_locals
    let (local this_contract) = get_contract_address()

    IERC20.transferFrom(contract_address=erc20_address, sender=address, recipient=this_contract, amount=Uint256(amount, 0))
    return ()
    end

#internal withdraw FUNC
func _withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):
    IERC20.transfer(contract_address=erc20_address, recipient=address, amount=Uint256(amount,0))
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
    return ()
end

##########
#EXTERNALS
##########

#TODO: make these functions safer by storing a mapping of valid erc20 addresses
#and requiring that the deposit and withdrawal are for valid erc20s
#also could do this in proxy contract

@external
func proxy_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):
    _require_call_from_proxy()

    _deposit(amount, address, erc20_address)
    return ()
end

@external
func proxy_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):
    _require_call_from_proxy()

    _withdraw(amount, address, erc20_address)
    return ()
end

@external
func proxy_approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, token_contract_address: felt, spender_address: felt):
    _require_call_from_proxy()

    IERC20.approve(contract_address=token_contract_address, spender=spender_address, amount=amount)
    return ()
end

##########
#VIEWS
##########

#For ETH just put ETH ERC20 address
@view
func get_ERC20_balance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(contract_address: felt) -> (res: felt):
    alloc_locals
    let (local this_contract) = get_contract_address()
    let (res) = IERC20.balanceOf(contract_address=contract_address, account=this_contract)
    return (res.low)
end