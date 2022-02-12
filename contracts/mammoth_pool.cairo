#Mammoth pool contract allowing following functionality:
#1. Deposit tokens
#2. Withdraw tokens
#3. whitelisted MM access to atomic swaps with liquidity
#4. controls on trades that can be executed
#5. view token balance

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.uint256 import Uint256

from contracts.lib.openzeppelin.contracts.Ownable_base import (
    Ownable_initializer,
    Ownable_only_owner
)
from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

##########
#INTERFACES
##########

@contract_interface
namespace IERC20:
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func decimals() -> (decimals: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
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
    }(proxy: felt, owner: felt):
    _proxy.write(proxy)
    Ownable_initializer(owner)
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
    }(amount: Uint256, address: felt, erc20_address: felt) -> ():
    alloc_locals
    let (local this_contract) = get_contract_address()

    IERC20.transferFrom(contract_address=erc20_address, sender=address, recipient=this_contract, amount=amount)
    return (TRUE)
    end

#internal withdraw FUNC
func _withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt, erc20_address: felt):
    IERC20.transfer(contract_address=erc20_address, recipient=address, amount=amount)
    return (TRUE)
end

##########
#HELPERS
##########

#helper function to require call from proxy
func Only_proxy{
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

@external
func proxy_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):
    Only_proxy()

    _deposit(amount, address, erc20_address)
    return (TRUE)
end

@external
func proxy_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):
    Only_proxy(TRUE)

    _withdraw(amount, address, erc20_address)
    return ()
end

##########
#SETTERS
##########

@external
func set_proxy{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_proxy: felt):
    Ownable_only_owner()

    _proxy.write(new_proxy)
    return(TRUE)
end

##########
#VIEWS
##########

@view
func get_ERC20_balance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(erc20_address: felt) -> (res: felt):
    alloc_locals
    let (local this_contract) = get_contract_address()
    let (res) = IERC20.balanceOf(contract_address=erc20_address, account=this_contract)
    return (res)
end