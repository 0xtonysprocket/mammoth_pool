# Mammoth pool contract allowing following functionality:
# 1. Deposit tokens
# 2. Withdraw tokens
# 3. whitelisted MM access to atomic swaps with liquidity
# 4. controls on trades that can be executed
# 5. view token balance

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem

# openzeppelin
from contracts.lib.openzeppelin.contracts.Ownable_base import (
    Ownable_initializer, Ownable_only_owner, Ownable_get_owner, Ownable_transfer_ownership)
from contracts.lib.openzeppelin.contracts.token.ERC20_base import (
    ERC20_name, ERC20_symbol, ERC20_totalSupply, ERC20_decimals, ERC20_balanceOf, ERC20_allowance,
    ERC20_initializer, ERC20_approve, ERC20_increaseAllowance, ERC20_decreaseAllowance,
    ERC20_transfer, ERC20_transferFrom, ERC20_mint, ERC20_burn)
from contracts.lib.openzeppelin.contracts.Initializable import initialize, initialized
from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

# mammoth
from contracts.lib.Pool_base import Pool_deposit, Pool_withdraw
from contracts.lib.Pool_registry_base import (
    Register_initialize_pool, Register_get_pool_info, Register_get_token_weight,
    Register_only_approved_erc20, Register_is_erc20_approved, ApprovedERC20)
from contracts.lib.balancer_math import (
    get_out_given_in, get_pool_minted_given_single_in, get_single_out_given_pool_in)
from contracts.lib.ratios.contracts.ratio import Ratio

@contract_interface
namespace IERC20:
    func balanceOf(account : felt) -> (balance : Uint256):
    end
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        router : felt, name : felt, symbol : felt, initial_supply : Uint256, recipient : felt):
    ERC20_initializer(name, symbol, initial_supply, recipient)
    Ownable_initializer(router)
    return ()
end

##########
# POOL FUNCTIONS
##########

@external
func deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt, erc20_address : felt) -> (success : felt):
    alloc_locals
    Ownable_only_owner()
    Register_only_approved_erc20(erc20_address)

    let (local pool_amount_to_mint : Uint256) = view_pool_minted_given_single_in(
        amount_to_deposit, erc20_address)
    let (local success : felt) = Pool_deposit(amount_to_deposit, user_address, erc20_address)

    with_attr error_message("DEPOSIT FAILED : POOL LEVEL"):
        assert success = TRUE
    end

    let (local mint_success : felt) = mint(user_address, pool_amount_to_mint)
    with_attr error_message("POOL LP MINT FAILURE"):
        assert mint_success = TRUE
    end

    return (TRUE)
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_in : Uint256, user_address : felt, erc20_address : felt) -> (success : felt):
    alloc_locals
    Ownable_only_owner()
    Register_only_approved_erc20(erc20_address)

    let (local amount_out : Uint256) = view_single_out_given_pool_in(pool_amount_in, erc20_address)
    let (local success : felt) = Pool_withdraw(amount_out, user_address, erc20_address)
    with_attr error_message("WITHDRAW FAILED : POOL LEVEL"):
        assert success = TRUE
    end

    let (local burn_success : felt) = burn(user_address, pool_amount_in)
    with_attr error_message("POOL LP BURN FAILURE"):
        assert burn_success = TRUE
    end

    return (TRUE)
end

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_in : Uint256, address : felt, erc20_address_in : felt, erc20_address_out : felt) -> (
        success : felt):
    alloc_locals
    Ownable_only_owner()
    Register_only_approved_erc20(erc20_address_in)
    Register_only_approved_erc20(erc20_address_out)

    let (local amount_out : Uint256) = view_out_given_in(
        amount_in, erc20_address_in, erc20_address_out)
    let (local deposit_success : felt) = Pool_deposit(amount_in, address, erc20_address_in)
    let (local withdraw_success : felt) = Pool_withdraw(amount_out, address, erc20_address_out)

    with_attr error_message("DEPOSIT FAILED IN SWAP : POOL LEVEL"):
        assert deposit_success = TRUE
    end
    with_attr error_message("WITHDRAW FAILED IN SWAP : POOL LEVEL"):
        assert withdraw_success = TRUE
    end

    return (TRUE)
end

@external
func initialize_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        caller_address : felt, s_fee : Ratio, e_fee : Ratio, erc_list_len : felt,
        erc_list : ApprovedERC20*) -> (bool : felt, lp_amount : Uint256):
    alloc_locals

    let (local success : felt, local lp_amount : Uint256) = Register_initialize_pool(
        caller_address, s_fee, e_fee, erc_list_len, erc_list)
    assert success = TRUE

    let (local mint_success : felt) = mint(caller_address, lp_amount)
    with_attr error_message("POOL LP MINT FAILURE IN INITIALIZE"):
        assert mint_success = TRUE
    end

    initialize()

    return (TRUE, lp_amount)
end

##########
# VIEW MATH
##########

@view
func view_single_out_given_pool_in{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_in : Uint256, erc20_address : felt) -> (amount_to_withdraw : Uint256):
    alloc_locals

    let (local this_contract : felt) = get_contract_address()

    let (local swap_fee : Ratio, local exit_fee : Ratio,
        total_weight : Ratio) = Register_get_pool_info()
    let (local a_weight : Ratio) = Register_get_token_weight(erc20_address)
    let (local supply : Uint256) = totalSupply()
    let (local a_balance : Uint256) = get_ERC20_balance(erc20_address)

    let (local ratio_out : Ratio) = get_single_out_given_pool_in(
        pool_amount_in, a_balance, supply, a_weight, total_weight, swap_fee, exit_fee)

    let (local amount_to_withdraw : Uint256, _) = uint256_unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_to_withdraw)
end

@view
func view_pool_minted_given_single_in{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, erc20_address : felt) -> (amount_to_mint : Uint256):
    alloc_locals

    let (local swap_fee : Ratio, _, total_weight : Ratio) = Register_get_pool_info()
    let (local a_weight : Ratio) = Register_get_token_weight(erc20_address)
    let (local supply : Uint256) = totalSupply()
    let (local a_balance : Uint256) = get_ERC20_balance(erc20_address)

    let (local ratio_out : Ratio) = get_pool_minted_given_single_in(
        amount_to_deposit, a_balance, supply, a_weight, total_weight, swap_fee)

    let (local amount_to_mint : Uint256, _) = uint256_unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_to_mint)
end

@view
func view_out_given_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_in : Uint256, erc20_address_in : felt, erc20_address_out : felt) -> (
        amount_out : Uint256):
    alloc_locals

    let (local swap_fee : Ratio, _, _) = Register_get_pool_info()
    let (local a_balance : Uint256) = get_ERC20_balance(erc20_address_in)
    let (local a_weight : Ratio) = Register_get_token_weight(erc20_address_in)
    let (local b_balance : Uint256) = get_ERC20_balance(erc20_address_out)
    let (local b_weight : Ratio) = Register_get_token_weight(erc20_address_out)

    let (local ratio_out : Ratio) = get_out_given_in(
        amount_in, a_balance, a_weight, b_balance, b_weight, swap_fee)

    let (local amount_out : Uint256, _) = uint256_unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_out)
end

@view
func get_ERC20_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        erc20_address : felt) -> (res : Uint256):
    alloc_locals
    let (local this_contract) = get_contract_address()
    let (res) = IERC20.balanceOf(contract_address=erc20_address, account=this_contract)
    return (res)
end

@view
func is_ERC20_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        erc20_address : felt) -> (approved : felt):
    alloc_locals
    let (approved : felt) = Register_is_erc20_approved(erc20_address)
    return (approved)
end

@view
func get_token_weight{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        erc20_address : felt) -> (approved : Ratio):
    alloc_locals
    let (weight : Ratio) = Register_get_token_weight(erc20_address)
    return (weight)
end

@view
func get_pool_into{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        erc20_address : felt) -> (swap_fee : Ratio, exit_fee : Ratio, total_weight : Ratio):
    alloc_locals
    let (s_fee : Ratio, e_fee : Ratio, t_w : Ratio) = Register_get_pool_info()
    return (s_fee, e_fee, t_w)
end

#########
# ERC20_mintable_burnable
#########

#
# Getters
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC20_name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC20_symbol()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        totalSupply : Uint256):
    let (totalSupply : Uint256) = ERC20_totalSupply()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        decimals : felt):
    let (decimals) = ERC20_decimals()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (balance : Uint256):
    let (balance : Uint256) = ERC20_balanceOf(account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt) -> (remaining : Uint256):
    let (remaining : Uint256) = ERC20_allowance(owner, spender)
    return (remaining)
end

#
# Externals
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256) -> (success : felt):
    ERC20_transfer(recipient, amount)
    return (TRUE)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    ERC20_transferFrom(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256) -> (success : felt):
    ERC20_approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, added_value : Uint256) -> (success : felt):
    ERC20_increaseAllowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, subtracted_value : Uint256) -> (success : felt):
    ERC20_decreaseAllowance(spender, subtracted_value)
    return (TRUE)
end

func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, amount : Uint256) -> (success : felt):
    ERC20_mint(to, amount)
    return (TRUE)
end

func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, amount : Uint256) -> (success : felt):
    ERC20_burn(account, amount)
    return (TRUE)
end
