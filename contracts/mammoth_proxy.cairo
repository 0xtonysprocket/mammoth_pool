%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

# proxy contract for depositing to Mammoth pool, receiving LP tokens, 
# and for MM to interact with mammoth pool liquidity 

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
    func proxy_mint(recipient: felt, amount: felt):
    end

    func proxy_burn(user: felt, amount: felt):
    end
end

@contract_interface
namespace IPoolContract:
    func proxy_approve(amount: felt, token_contract_address: felt, spender_address: felt):
    end

    func proxy_deposit(amount: felt, address: felt, erc20_address: felt):
    end

    func proxy_withdraw(amount: felt, address: felt, erc20_address: felt):
    end

    func proxy_distribute(erc20_address: felt):
    end
end

#ZigZagExchange
@contract_interface
namespace IExchangeContract:
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
#eventually inherit onlyOwner
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
    recipient:felt, amount: felt):
    alloc_locals
    let (local c) = token_address.read()
    ITokenContract.proxy_mint(contract_address=c, recipient=recipient, amount=amount)
    ret
end

func call_burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient:felt, amount: felt):
    alloc_locals
    let (local c) = token_address.read()
    ITokenContract.proxy_burn(contract_address=c, user=recipient, amount=amount)
    ret
end

##########
#POOL CONTRACT
##########

#TODO: make these calls safer by storing a list of valid erc20 addresses for the pool
#do this either here or in pool contract

func call_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):
    alloc_locals

    let (local pool) = pool_address.read()
    IPoolContract.proxy_deposit(contract_address=pool, amount=amount, address=address, erc20_address=erc20_address)
    ret
end

func call_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):
    alloc_locals

    let (local pool) = pool_address.read()
    IPoolContract.proxy_withdraw(contract_address=pool, amount=amount, address=address, erc20_address=erc20_address)
    ret
end

@external
func call_distribute{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(erc20_address: felt):
    alloc_locals

    let (local pool) = pool_address.read()
    IPoolContract.proxy_distribute(contract_address=pool, erc20_address=erc20_address)
    ret
end

##########
#MAMMOTH EXTERNALS
##########

#deposits eth into pool and mints mammoth LP tokens
@external
func mammoth_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):

    call_deposit(amount, address, erc20_address)
    call_mint(recipient=address, amount=amount)
    ret
end

@external
func mammoth_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, erc20_address: felt):

    call_withdraw(amount, address, erc20_address)
    call_burn(recipient=address, amount=amount)
    ret
end

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

#TODO: add approve_mm function called by owner only and approves MM to spend token from pool contract

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

#token_contract_address should be address of ETH ERC20
#exchange address should be zigzag exchange address for now
@external
func call_approve_mammoth_pool_liquidity{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, token_contract_address: felt, exchange_address: felt):
    alloc_locals
    call _require_call_from_owner

    let (local pool) = pool_address.read()
    #TODO: fix the .low in amount in next line
    IPoolContract.proxy_approve(contract_address=pool, amount=amount, token_contract_address=token_contract_address, spender_address=exchange_address)
    ret
end

#func APPROVE liquidity from pool contract for swap on exchange contract
#require call from MM

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
    IExchangeContract.fill_order(contract_address, buy_order, sell_order, fill_price, base_fill_quantity)
    ret
end

##########
#VIEWS
##########

@view
func get_token_address{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    alloc_locals
    let (local ta) = token_address.read()
    return (ta)
end

@view
func get_pool_address{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    alloc_locals
    let (local pa) = pool_address.read()
    return (pa)
end


