%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.access.ownable import Ownable
from contracts.lib.bool import TRUE, FALSE
from contracts.lib.Pool_base import Pool_deposit, Pool_withdraw

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(router : felt):
    Ownable.initializer(router)
    return ()
end

@external
func deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, address : felt, erc20_address : felt) -> (success : felt):
    Ownable.assert_only_owner()

    Pool_deposit(amount, address, erc20_address)
    return (TRUE)
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, address : felt, erc20_address : felt) -> (success : felt):
    Ownable.assert_only_owner()

    Pool_withdraw(amount, address, erc20_address)
    return (TRUE)
end
