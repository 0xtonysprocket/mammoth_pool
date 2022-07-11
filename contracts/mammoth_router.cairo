%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_contract_address

# OZ
from openzeppelin.access.ownable import Ownable
from openzeppelin.security.initializable import Initializable, Initializable_initialized

# Mammoth
from contracts.lib.ratios.contracts.ratio import Ratio
from contracts.lib.Router_base import Router
from contracts.lib.Pool_registry_base import ApprovedERC20

############
# EVENTS
############

@event
func pool_deployed(pool_address : felt, pool_type : felt):
end

@event
func pool_created(
        pool : felt, name : felt, symbol : felt, decimals : felt, swap_fee : Ratio,
        exit_fee : Ratio, tokens_len : felt, tokens : ApprovedERC20*, initial_lp_minted : Uint256):
end

@event
func deposit_single_called(token : felt, pool : felt, amount_deposited : Uint256):
end

@event
func deposit_proportional_called(pool : felt, lp_out : Uint256):
end

@event
func withdraw_single_called(token : felt, pool : felt, amount_withdrawn : Uint256):
end

@event
func withdraw_proportional_called(pool : felt, lp_in : Uint256):
end

@event
func swap_called(token_in : felt, token_out : felt, pool : felt, amount_swapped_in : Uint256):
end

############
# Initializer
############

@external
func initialize{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner_address : felt):
    require_not_initialized()
    Ownable.initializer(owner_address)

    # set as initialized
    Initializable.initialize()
    return ()
end

############
# CREATE POOL
############

@external
func deploy_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_type : felt, proxy_admin : felt) -> (pool_address : felt):
    alloc_locals
    Ownable.assert_only_owner()

    # deploy pool
    let (local pool_address : felt) = Router.deploy_pool(pool_type, proxy_admin)

    pool_deployed.emit(pool_address=pool_address, pool_type=pool_type)

    return (pool_address)
end

@external
func create_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_address : felt, name : felt, symbol : felt, decimals : felt, caller_address : felt,
        s_fee : Ratio, e_fee : Ratio, erc_list_len : felt, erc_list : ApprovedERC20*) -> (
        bool : felt):
    alloc_locals
    Ownable.assert_only_owner()

    # setup pool [set name, symbol, decimals, and owner]
    let (local this_contract : felt) = get_contract_address()
    Router.setup_pool(this_contract, name, symbol, decimals, pool_address)

    # init pool [set fees, ERCs, weights, supply initial liquidity]
    let (local success : felt, local lp_amount : Uint256) = Router.init_pool(
        caller_address, pool_address, s_fee, e_fee, erc_list_len, erc_list)

    with_attr error_message("POOL CREATION FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end

    pool_created.emit(
        pool=pool_address,
        name=name,
        symbol=symbol,
        decimals=decimals,
        swap_fee=s_fee,
        exit_fee=e_fee,
        tokens_len=erc_list_len,
        tokens=erc_list,
        initial_lp_minted=lp_amount)

    return (TRUE)
end

############
# DEPOSIT WITHDRAW SWAP
############

@external
func mammoth_deposit_single_asset{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, user_address : felt, pool_address : felt, erc20_address : felt) -> (
        success : felt):
    alloc_locals

    deposit_single_called.emit(token=erc20_address, pool=pool_address, amount_deposited=amount)

    Router.only_approved_pool(pool_address)
    let (local success : felt) = Router.call_deposit_single_asset(
        amount, user_address, pool_address, erc20_address)

    with_attr error_message("DEPOSIT FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end
    return (TRUE)
end

@external
func mammoth_proportional_deposit{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_out : Uint256, user_address : felt, pool_address : felt) -> (success : felt):
    alloc_locals

    deposit_proportional_called.emit(pool=pool_address, lp_out=pool_amount_out)

    Router.only_approved_pool(pool_address)
    let (local success : felt) = Router.call_deposit_proportional_assets(
        pool_amount_out, user_address, pool_address)

    with_attr error_message("DEPOSIT FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end
    return (TRUE)
end

@external
func mammoth_withdraw_single_asset{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, user_address : felt, pool_address : felt, erc20_address : felt) -> (
        success : felt):
    alloc_locals

    withdraw_single_called.emit(token=erc20_address, pool=pool_address, amount_withdrawn=amount)

    Router.only_approved_pool(pool_address)
    let (local success : felt) = Router.call_withdraw_single_asset(
        amount, user_address, pool_address, erc20_address)

    with_attr error_message("WITHDRAW FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end
    return (TRUE)
end

@external
func mammoth_proportional_withdraw{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_in : Uint256, user_address : felt, pool_address : felt) -> (success : felt):
    alloc_locals

    withdraw_proportional_called.emit(pool=pool_address, lp_in=pool_amount_in)

    Router.only_approved_pool(pool_address)
    let (local success : felt) = Router.call_withdraw_proportional_assets(
        pool_amount_in, user_address, pool_address)

    with_attr error_message("WITHDRAW FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end
    return (TRUE)
end

@external
func mammoth_swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256, user_address : felt, pool_address : felt, erc20_address_in : felt,
        erc20_address_out : felt) -> (success : felt):
    alloc_locals

    swap_called.emit(
        token_in=erc20_address_in,
        token_out=erc20_address_out,
        pool=pool_address,
        amount_swapped_in=amount)

    Router.only_approved_pool(pool_address)
    let (local success : felt) = Router.call_swap(
        amount, user_address, pool_address, erc20_address_in, erc20_address_out)

    with_attr error_message("SWAP FAILED : ROUTER LEVEL"):
        assert success = TRUE
    end

    return (TRUE)
end

#########
# SETTERS
#########

@external
func set_proxy_class_hash{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        proxy_class_hash : felt) -> (bool : felt):
    Ownable.assert_only_owner()
    Router.set_proxy_class_hash(proxy_class_hash)
    return (TRUE)
end

# pool type should be a short string, default is the only type currently
# but if we design more pools we can put the class hash here
@external
func define_pool_type_class_hash{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_type : felt, pool_class_hash : felt) -> (bool : felt):
    Ownable.assert_only_owner()
    Router.define_pool_type_class_hash(pool_type, pool_class_hash)
    return (TRUE)
end

#########
# OWNABLE
#########

@view
func get_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        owner : felt):
    let (owner) = Ownable.owner()
    return (owner=owner)
end

@external
func transfer_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_owner : felt) -> (new_owner : felt):
    Ownable.transfer_ownership(new_owner)
    return (new_owner=new_owner)
end

########
# VIEW
########

@view
func is_pool_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_address : felt) -> (bool : felt):
    alloc_locals
    let (local success : felt) = Router.pool_approved(pool_address)
    return (success)
end

#########
# REQUIRE FUNCTION
#########

@view
func require_not_initialized{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    let (local initialized : felt) = Initializable_initialized.read()

    with_attr error_message("ERROR POOL ALREADY INITIALIZED"):
        assert initialized = 0
    end

    return ()
end
