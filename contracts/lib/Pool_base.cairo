# implements deposit and withdraw with ERC20 interface

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

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

func Pool_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt, erc20_address: felt) -> ():
    alloc_locals
    let (local this_contract) = get_contract_address()

    IERC20.transferFrom(contract_address=erc20_address, sender=address, recipient=this_contract, amount=amount)
    return (TRUE)
end

func Pool_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256, address: felt, erc20_address: felt):
    IERC20.transfer(contract_address=erc20_address, recipient=address, amount=amount)
    return (TRUE)
end