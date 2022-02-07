%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math import (assert_not_zero, assert_le, unsigned_div_rem)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

from lib.local_cairo.balancer_math import (get_spot_price, get_pool_minted_given_single_in, get_single_out_given_pool_in, get_out_given_in)
from lib.local_cairo.ratio import Ratio, ratio_add

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

    func get_total_supply():
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

    func get_total_staked(erc20_address: felt):
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
func lp_token_address(pool_address: felt) -> (contract_address: felt):
end

#store the address of the pool contract
@storage_var
func approved_pool_address(pool_address: felt) -> (bool: felt):
end

#store market maker address
@storage_var
func approved_market_makers(market_maker_address: felt) -> (bool: felt):
end

#approved erc20s
@storage_var
func approved_erc20s(pool_address: felt, erc20_address: felt) -> (bool: felt):
end

#pool weight of a given erc20 (1/w)
@storage_var
func token_weight(pool_address: felt, erc20_address: felt) -> (weight: Ratio):
end

#sum of all weights for normalization
@storage_var
func total_weight(pool_address: felt) -> (total_weight: Ratio):
end

#swap fee
@storage_var
func swap_fee(pool_address: felt) -> (fee: Ratio):
end

#exit fee
@storage_var
func exit_fee(pool_address: felt) -> (fee: Ratio):
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
    return ()
end

func call_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
    pool_address: felt,
    recipient: felt, 
    amount: felt):
    let (lp_address) = lp_token_address.read(pool_address)
    ITokenContract.proxy_mint(contract_address=lp_address, recipient=recipient, amount=amount)
    return ()
end

func call_burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pool_address: felt,
    recipient: felt, 
    amount: felt):
    let (lp_address) = lp_token_address.read(pool_address)
    ITokenContract.proxy_burn(contract_address=lp_address, user=recipient, amount=amount)
    return ()
end

##########
#POOL CONTRACT
##########

func call_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, pool_address: felt, erc20_address: felt):
    IPoolContract.proxy_deposit(contract_address=pool_address, amount=amount, address=address, erc20_address=erc20_address)
    return ()
end

func call_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: felt, address: felt, pool_address: felt, erc20_address: felt):
    IPoolContract.proxy_withdraw(contract_address=pool_address, amount=amount, address=address, erc20_address=erc20_address)
    return ()
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
    }(amount_to_deposit: felt, user_address: felt, pool_address: felt, erc20_address: felt):
    require_approved_pool(pool_address)
    require_approved_erc20_for_pool(pool_address, erc20_address)

    let amount_to_mint: felt = view_pool_minted_given_single_in(amount_to_deposit, pool_address, erc20_address)
    call_deposit(amount_to_deposit, user_address, pool_address, erc20_address)
    call_mint(pool_address=pool_address, recipient=user_address, amount=amount_to_mint)
    return ()
end

@external
func mammoth_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_amount_in: felt, user_address: felt, pool_address: felt, erc20_address: felt):
    require_approved_pool(pool_address)
    require_approved_erc20_for_pool(pool_address, erc20_address)

    let amount_to_withdraw: felt = view_single_out_given_pool_in(pool_amount_in, pool_address, erc20_address)
    call_withdraw(amount_to_withdraw, user_address, pool_address, erc20_address)
    call_burn(pool_address=pool_address, recipient=user_address, amount=pool_amount_in)
    return ()
end

@external
func mammoth_swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_in: felt, user_address: felt, pool_address: felt, erc20_address_in: felt, erc20_address_out: felt):
    require_approved_pool(pool_address)
    require_approved_erc20_for_pool(pool_address, erc20_address_in)
    require_approved_erc20_for_pool(pool_address, erc20_address_out)

    let amount_out: felt = view_out_given_in(amount_in, pool_address, erc20_address_in, erc20_address_out)
    call_deposit(amount_in, user_address, pool_address, erc20_address_in)
    call_withdraw(amount_out, user_address, pool_address, erc20_address_out)
    return()
end

##########
#MATH
##########

@view
func view_single_out_given_pool_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_amount_in: felt, pool_address: felt, erc20_address: felt) -> (amount_to_withdraw: felt):
    alloc_locals

    # needed for dereferencing struct
    let (__fp__, _) = get_fp_and_pc()

    let lp_address: felt = lp_token_address.read(pool_address)
    let supply_uint: Uint256 = ITokenContract.get_total_supply(contract_address=lp_address)
    let supply: felt = supply_uint.low
    let a_balance: felt = IPoolContract.get_total_staked(contract_address=pool_address, erc20_address=erc20_address)
    let a_weight: Ratio = token_weight.read(pool_address, erc20_address)
    let t_weight: Ratio = total_weight.read(pool_address)
    let s_fee: Ratio = swap_fee.read(pool_address)
    let e_fee: Ratio = exit_fee.read(pool_address)

    let ratio_out: Ratio = get_single_out_given_pool_in(pool_amount_in, a_balance, supply, a_weight, t_weight, s_fee, e_fee)
    let (amount_to_withdraw: felt, _) = unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_to_withdraw)
end

@view
func view_pool_minted_given_single_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_to_deposit: felt, pool_address: felt, erc20_address: felt) -> (amount_to_withdraw: felt):
    # needed for dereferencing struct
    let (__fp__, _) = get_fp_and_pc()

    let lp_address: felt = lp_token_address.read(pool_address)
    let supply_uint: Uint256 = ITokenContract.get_total_supply(contract_address=lp_address)
    let supply: felt = supply_uint.low
    let a_balance: felt = IPoolContract.get_total_staked(contract_address=pool_address, erc20_address=erc20_address)
    let a_weight: Ratio = token_weight.read(pool_address, erc20_address)
    let t_weight: Ratio = total_weight.read(pool_address)
    let s_fee: Ratio = swap_fee.read(pool_address)

    let ratio_minted: Ratio = get_pool_minted_given_single_in(amount_to_deposit, a_balance, supply, a_weight, t_weight, s_fee)
    let (amount_to_mint: felt, _) = unsigned_div_rem(ratio_minted.n, ratio_minted.d)

    return (amount_to_mint)
end

@view
func view_out_given_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount_in: felt, pool_address: felt, erc20_address_in: felt, erc20_address_out: felt) -> (amount_out: felt):
    # needed for dereferencing struct
    let (__fp__, _) = get_fp_and_pc()

    let a_balance: felt = IPoolContract.get_total_staked(contract_address=pool_address, erc20_address=erc20_address_in)
    let a_weight: Ratio = token_weight.read(pool_address, erc20_address_in)
    let b_balance: felt = IPoolContract.get_total_staked(contract_address=pool_address, erc20_address=erc20_address_out)
    let b_weight: Ratio = token_weight.read(pool_address, erc20_address_out)
    let s_fee: Ratio = swap_fee.read(pool_address)

    let ratio_out: Ratio = get_out_given_in(  amount_in, a_balance, a_weight, b_balance, b_weight, s_fee)
    let (amount_out: felt, _) = unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_out)
end

##########
#Require Functions
##########

@view
func require_call_from_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (caller_address: felt) = get_caller_address()
    let (approved_caller: felt) = owner.read()
    assert caller_address = approved_caller
    return ()
end

@view
func require_approved_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt):
    let (approval: felt) = approved_pool_address.read(pool_address)
    assert approval = 1
    return ()
end
    

@view
func require_approved_erc20_for_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt, erc20_address: felt):
    let (approval: felt) =  approved_erc20s.read(pool_address, erc20_address)
    assert approval = 1
    return ()
end

##########
#Setters
##########

@external
func create_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(lp_address: felt, pool_address: felt, s_fee: Ratio, e_fee: Ratio):
    require_call_from_owner()

    approved_pool_address.write(pool_address, 1)
    lp_token_address.write(pool_address, lp_address)
    swap_fee.write(pool_address, s_fee)
    exit_fee.write(pool_address, e_fee)
    return ()
end

@external
func approve_market_maker_contract_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(address: felt):
    require_call_from_owner()

    approved_market_makers.write(address, 1)
    return ()
end

@external
func add_approved_erc20_for_pool{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt, erc20_address: felt, weight: Ratio):
    require_call_from_owner()

    approved_erc20s.write(pool_address, erc20_address, 1)
    token_weight.write(pool_address, erc20_address, weight)
    
    #ALERT: RIGHT NOW MANUALLY SET TOTAL WEIGHT AT 1/1 so on us to make sure that is the case
    total_weight.write(pool_address, Ratio(1,1))
    return()
end

#TODO: add approve_mm function called by owner only and approves MM to spend token from pool contract

##########
#Market Maker Functions
##########

func require_call_from_mm{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (local caller_address: felt) = get_caller_address()
    let (local approved_caller: felt) = approved_market_makers.read(caller_address)
    assert approved_caller = 1
    return ()
end

#not sure if we need this function yet
#token_contract_address should be address of ETH ERC20
#exchange address should be zigzag exchange address for now
#@external
#func call_approve_mammoth_pool_liquidity{
#        syscall_ptr : felt*, 
#        pedersen_ptr : HashBuiltin*,
#        range_check_ptr
#    }(amount: felt, token_contract_address: felt, exchange_address: felt):
#    alloc_locals
#    require_call_from_owner()

#    let (local pool) = pool_address.read()
#    #TODO: fix the .low in amount in next line
#    IPoolContract.proxy_approve(contract_address=pool, amount=amount, token_contract_address=token_contract_address, spender_address=exchange_address)
#    return ()
#end

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
    
    require_call_from_mm()
    IExchangeContract.fill_order(contract_address, buy_order, sell_order, fill_price, base_fill_quantity)
    return ()
end

##########
#VIEWS
##########

@view
func get_token_address_for_pool{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt) -> (address: felt):
    alloc_locals
    let (local ta) = lp_token_address.read(pool_address)
    return (ta)
end

@view
func get_swap_fee_for_pool{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt) -> (fee: Ratio):
    alloc_locals
    let (local ta) = swap_fee.read(pool_address)
    return (ta)
end

@view
func get_exit_fee_for_pool{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt) -> (fee: Ratio):
    alloc_locals
    let (local ta) = exit_fee.read(pool_address)
    return (ta)
end


@view
func is_pool_approved{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(address: felt) -> (bool: felt):
    alloc_locals
    let (local pa) = approved_pool_address.read(address)
    return (pa)
end

@view
func is_erc20_approved{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt, erc20_address: felt) -> (bool: felt):
    alloc_locals
    let (local bool) = approved_erc20s.read(pool_address, erc20_address)
    return (bool)
end

@view
func get_weight_for_token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pool_address: felt, erc20_address: felt) -> (weight: Ratio):
    alloc_locals
    let (local ta) = token_weight.read(pool_address, erc20_address)
    return (ta)
end

