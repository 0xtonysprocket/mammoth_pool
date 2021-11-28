%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

# proxy contract for depositing to Mammoth pool and receiving LP tokens
#also proxy for whitelised MM

##########
#STRUCTS
##########

struct PriceRatio:
    member numerator: felt
    member denominator: felt
end

struct Order:
    member chain_id : felt
    member user : felt
    member base_asset : felt
    member quote_asset : felt
    member side : felt # 0 = buy, 1 = sell
    member base_quantity : felt
    member price : PriceRatio
    member expiration : felt
    member sig_r: felt
    member sig_s: felt
end

##########
#INTERFACES
##########

@contract_interface
namespace ITokenContract:
    func proxy_mint(recipient: felt, amount: Uint256):
    end

    func proxy_burn(user: felt, amount: Uint256):
    end
end

#ZigZagExchange
@contract_interface
namespace ExchangeContract:
    func fill_order(
        buy_order: Order, 
        sell_order: Order,  
        fill_price: PriceRatio,
        base_fill_quantity: felt):
    end
end

##########
#STORAGE VAR AND CONSTRUCTOR
##########

#store owner address
@storage_var
func owner() -> (address: felt):
end

#store the address of the token contract
@storage_var
func token_address() -> (contract_address: felt):
end

#store the address of the pool contract
@storage_var
func pool_address() -> (contract_address: felt):
end

#store market maker address
@storage_var
func market_maker_address() -> (market_maker_address: felt):
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        owner_address: felt,
    ):
    owner.write(owner_address)
    ret
end

func call_mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient:felt, amount: Uint256):
    let (c) = token_address.read()
    ITokenContract.proxy_mint(contract_address=c, recipient=recipient, amount=amount)
    ret
end

func call_burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient:felt, amount: Uint256):
    let (c) = token_address.read()
    ITokenContract.proxy_burn(contract_address=c, user=recipient, amount=amount)
    ret
end

##########
#FUNCTIONALITY TO BE IMPLEMENTED FOR DEPOSIT AND WITHDRAWAL
##########

#func call_deposit
#input (amount, address)

#IPoolContract.proxy_deposit(amount, address)
#END

#func call_withdraw
#input (amount, address)

#IPoolContract.proxy_withdraw(amount, address)
#END

#func mammoth_deposit
#input (amount, address)

#call_deposit(amount, address)
#call_mint(amount, address)
#END

#func mammoth_withdraw
#input (amount, address)

#get caller address
#call_withdraw(amount, address)
#call_burn(amount, address)
#END

##########
#Require Owner
##########

func _require_call_from_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (local caller_address: felt) = get_caller_address()
    let (local approved_caller: felt) = owner.read()
    assert caller_address = approved_caller
    ret
end

##########
#Setters
##########

@external
func set_token_contract_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(address: felt):
    call _require_call_from_owner

    token_address.write(address)
    ret
end

@external
func set_pool_contract_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(address: felt):
    call _require_call_from_owner

    pool_address.write(address)
    ret
end

@external
func set_market_maker_contract_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(address: felt):
    call _require_call_from_owner

    market_maker_address.write(address)
    ret
end

##########
#Market Maker Functions
##########

func _require_call_from_mm{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (local caller_address: felt) = get_caller_address()
    let (local approved_caller: felt) = market_maker_address.read()
    assert caller_address = approved_caller
    ret
end

#TODO: add in approval for MM to transfer tokens from the pool
@external
func call_fill_order{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*,
    ecdsa_ptr : SignatureBuiltin*,
    range_check_ptr}(
    contract_address: felt,
    buy_order: Order, 
    sell_order: Order,  
    fill_price: PriceRatio,
    base_fill_quantity: felt):
    
    call _require_call_from_mm
    ExchangeContract.fill_order(contract_address, buy_order, sell_order, fill_price, base_fill_quantity)
    ret
end


