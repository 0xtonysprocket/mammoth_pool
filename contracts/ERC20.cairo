%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_le, assert_lt
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

#implements ERC20 starndard and add functions for proxy call
#add in requirements that only proxy can call mint and burn

#
# Storage
#

@storage_var
func _name() -> (res: felt):
end

@storage_var
func _symbol() -> (res: felt):
end

@storage_var
func balances(account: felt) -> (res: felt):
end

@storage_var
func allowances(owner: felt, spender: felt) -> (res: felt):
end

@storage_var
func total_supply() -> (res: felt):
end

@storage_var
func decimals() -> (res: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        recipient: felt
    ):
    # get_caller_address() returns '0' in the constructor;
    # therefore, recipient parameter is included
    _name.write(name)
    _symbol.write(symbol)
    decimals.write(18)
    _mint(recipient, 100000)
    return ()
end

#
# Getters
#

@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = _name.read()
    return (res)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = _symbol.read()
    return (res)
end

@view
func get_total_supply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res: felt) = total_supply.read()
    return (res)
end

@view
func get_decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = decimals.read()
    return (res)
end

@view
func balance_of{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (res: felt):
    let (res: felt) = balances.read(account=account)
    return (res)
end

@view
func allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (res: felt):
    let (res: felt) = allowances.read(owner=owner, spender=spender)
    return (res)
end

#
# Internals
#

func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: felt):
    alloc_locals
    assert_not_zero(recipient)

    let (balance: felt) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    balances.write(recipient, balance + amount)

    let (local supply: felt) = total_supply.read()

    total_supply.write(supply + amount)
    return ()
end

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: felt):
    alloc_locals
    assert_not_zero(sender)
    assert_not_zero(recipient)

    let (local sender_balance: felt) = balances.read(account=sender)

    # validates amount <= sender_balance and returns 1 if true
    assert_le(amount, sender_balance)

    # subtract from sender
    balances.write(sender, sender_balance - amount)

    # add to recipient
    let (recipient_balance: felt) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    balances.write(recipient, recipient_balance + amount)
    return ()
end

func _approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(caller: felt, spender: felt, amount: felt):
    assert_not_zero(caller)
    assert_not_zero(spender)
    allowances.write(caller, spender, amount)
    return ()
end

func _burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt, amount: felt):
    alloc_locals
    assert_not_zero(account)

    let (balance: felt) = balances.read(account)
    # validates amount <= balance and returns 1 if true
    assert_le(amount, balance)
    
    balances.write(account, balance - amount)

    let (supply: felt) = total_supply.read()
    total_supply.write(supply - amount )
    return ()
end

#
# Externals
#

@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

@external
func transfer_from{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: felt):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance: felt) = allowances.read(owner=sender, spender=caller)

    # validates amount <= caller_allowance and returns 1 if true   
    #NOTE MUST UNCOMMENT THIS LINE
    #assert_le(amount, caller_allowance)

    _transfer(sender, recipient, amount)

    # subtract allowance
    allowances.write(sender, caller, caller_allowance - amount)
    return ()
end

@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: felt):
    let (caller) = get_caller_address()
    _approve(caller, spender, amount)
    return ()
end

@external
func increase_allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: felt):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local current_allowance: felt) = allowances.read(caller, spender)

    # add allowance

    _approve(caller, spender, current_allowance + added_value)
    return()
end

@external
func decrease_allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: felt):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local current_allowance: felt) = allowances.read(owner=caller, spender=spender)

    # validates new_allowance < current_allowance and returns 1 if true   
    assert_lt(current_allowance - subtracted_value, current_allowance)

    _approve(caller, spender, current_allowance - subtracted_value)
    return()
end

#
# Test functions — will remove once extensibility is resolved
#

@external
func mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: felt):
    _mint(recipient, amount)
    return()
end

@external
func burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(user: felt, amount: felt):
    _burn(user, amount)
    return()
end
