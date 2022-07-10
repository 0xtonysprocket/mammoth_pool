# Mammoth pool contract allowing following functionality:
# 1. Deposit tokens
# 2. Withdraw tokens
# 3. swap

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem
from starkware.cairo.common.bool import TRUE, FALSE

# openzeppelin
from openzeppelin.access.ownable import Ownable
from openzeppelin.token.erc20.library import ERC20
from openzeppelin.security.initializable import Initializable

# mammoth
from contracts.lib.Pool_base import Pool
from contracts.lib.Pool_registry_base import Register, ApprovedERC20
from contracts.lib.balancer_math import Balancer_Math, TokenAndAmount
from contracts.lib.ratios.contracts.ratio import Ratio

@contract_interface
namespace IERC20:
    func balanceOf(account : felt) -> (balance : Uint256):
    end
end

##########
# INITIALIZE POOL
##########

# these function replaces the constructor

func setup_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        router : felt, name : felt, symbol : felt, decimals : felt):
    # set lp token name, symbol, and decimals
    ERC20.initializer(name, symbol, decimals)

    # set factory as owner
    Ownable.initializer(router)
    return ()
end

func initialize_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        caller_address : felt, s_fee : Ratio, e_fee : Ratio, erc_list_len : felt,
        erc_list : ApprovedERC20*) -> (bool : felt, lp_amount : Uint256):
    alloc_locals

    # approve the desired tokens
    # set swap fee
    # set exit fee
    # set token weights
    # make initial deposits
    let (local success : felt, local lp_amount : Uint256) = Register.initialize_pool(
        caller_address, s_fee, e_fee, erc_list_len, erc_list)
    assert success = TRUE

    # mint initial LP tokens
    let (local mint_success : felt) = mint(caller_address, lp_amount)
    with_attr error_message("POOL LP MINT FAILURE IN INITIALIZE"):
        assert mint_success = TRUE
    end

    # set as initialized
    Initializable.initialize()

    return (TRUE, lp_amount)
end

##########
# POOL FUNCTIONS
##########

@external
func deposit_single_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt, erc20_address : felt) -> (success : felt):
    alloc_locals
    Ownable.assert_only_owner()
    Register.only_approved_erc20(erc20_address)

    let (local pool_amount_to_mint : Uint256) = view_pool_minted_given_single_in(
        amount_to_deposit, erc20_address)
    let (local success : felt) = Pool.deposit(amount_to_deposit, user_address, erc20_address)

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
func deposit_proportional_assets{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_out : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    let (local list_of_tokens_and_deposit_balances_len : felt,
        local list_of_tokens_and_deposit_balances : TokenAndAmount*) = view_proportional_deposits_given_pool_out(
        pool_amount_out)

    # deposit using recursion
    let (local success : felt) = _recursive_deposit(
        list_of_tokens_and_deposit_balances_len, list_of_tokens_and_deposit_balances, user_address)

    let (local mint_success : felt) = mint(user_address, pool_amount_out)

    with_attr error_message("POOL LP MINT FAILURE"):
        assert mint_success = TRUE
    end

    return (success)
end

# proportional deposit recursion helper
func _recursive_deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        list_len : felt, list : TokenAndAmount*, user_address) -> (success : felt):
    alloc_locals

    if list_len == 0:
        return (TRUE)
    end

    # needed for dereferencing struct
    let (__fp__, _) = get_fp_and_pc()

    let current_struct : TokenAndAmount* = [&list]

    Register.only_approved_erc20(current_struct.erc_address)
    let (local success : felt) = Pool.deposit(
        current_struct.amount, user_address, current_struct.erc_address)

    with_attr error_message("DEPOSIT FAILED : POOL LEVEL"):
        assert success = TRUE
    end

    let (local complete_success : felt) = _recursive_deposit(
        list_len - 1, list + TokenAndAmount.SIZE, user_address)

    return (complete_success)
end

@external
func withdraw_single_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_in : Uint256, user_address : felt, erc20_address : felt) -> (success : felt):
    alloc_locals
    Ownable.assert_only_owner()
    Register.only_approved_erc20(erc20_address)

    let (local amount_out : Uint256) = view_single_out_given_pool_in(pool_amount_in, erc20_address)
    let (local success : felt) = Pool.withdraw(amount_out, user_address, erc20_address)
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
func withdraw_proportional_assets{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_in : Uint256, user_address : felt) -> (success : felt):
    alloc_locals
    Ownable.assert_only_owner()

    let (local list_len : felt, list : TokenAndAmount*) = view_proportional_withdraw_given_pool_in(
        pool_amount_in)

    # withdraw using recursion
    let (local success : felt) = _recursive_withdraw(list_len, list, user_address)

    let (local burn_success : felt) = burn(user_address, pool_amount_in)
    with_attr error_message("POOL LP BURN FAILURE"):
        assert burn_success = TRUE
    end

    return (TRUE)
end

# proportional withdraw recursion helper
func _recursive_withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        list_len : felt, list : TokenAndAmount*, user_address) -> (success : felt):
    alloc_locals

    if list_len == 0:
        return (TRUE)
    end

    # needed for dereferencing struct
    let (__fp__, _) = get_fp_and_pc()

    let current_struct : TokenAndAmount* = [&list]

    Register.only_approved_erc20(current_struct.erc_address)
    let (local success : felt) = Pool.withdraw(
        current_struct.amount, user_address, current_struct.erc_address)

    with_attr error_message("WITHDRAW FAILED : POOL LEVEL"):
        assert success = TRUE
    end

    let (local complete_success : felt) = _recursive_withdraw(
        list_len - 1, list + TokenAndAmount.SIZE, user_address)

    return (complete_success)
end

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_in : Uint256, address : felt, erc20_address_in : felt, erc20_address_out : felt) -> (
        success : felt):
    alloc_locals
    Ownable.assert_only_owner()
    Register.only_approved_erc20(erc20_address_in)
    Register.only_approved_erc20(erc20_address_out)

    let (local amount_out : Uint256) = view_out_given_in(
        amount_in, erc20_address_in, erc20_address_out)
    let (local deposit_success : felt) = Pool.deposit(amount_in, address, erc20_address_in)
    let (local withdraw_success : felt) = Pool.withdraw(amount_out, address, erc20_address_out)

    with_attr error_message("DEPOSIT FAILED IN SWAP : POOL LEVEL"):
        assert deposit_success = TRUE
    end
    with_attr error_message("WITHDRAW FAILED IN SWAP : POOL LEVEL"):
        assert withdraw_success = TRUE
    end

    return (TRUE)
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
        total_weight : Ratio) = Register.get_pool_info()
    let (local a_weight : Ratio) = Register.get_token_weight(erc20_address)
    let (local supply : Uint256) = totalSupply()
    let (local a_balance : Uint256) = get_ERC20_balance(erc20_address)

    let (local ratio_out : Ratio) = Balancer_Math.get_single_out_given_pool_in(
        pool_amount_in, a_balance, supply, a_weight, total_weight, swap_fee, exit_fee)

    let (local amount_to_withdraw : Uint256, _) = uint256_unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_to_withdraw)
end

@view
func view_pool_minted_given_single_in{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, erc20_address : felt) -> (amount_to_mint : Uint256):
    alloc_locals

    let (local swap_fee : Ratio, _, total_weight : Ratio) = Register.get_pool_info()
    let (local a_weight : Ratio) = Register.get_token_weight(erc20_address)
    let (local supply : Uint256) = totalSupply()
    let (local a_balance : Uint256) = get_ERC20_balance(erc20_address)

    let (local ratio_out : Ratio) = Balancer_Math.get_pool_minted_given_single_in(
        amount_to_deposit, a_balance, supply, a_weight, total_weight, swap_fee)

    let (local amount_to_mint : Uint256, _) = uint256_unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_to_mint)
end

@view
func view_out_given_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_in : Uint256, erc20_address_in : felt, erc20_address_out : felt) -> (
        amount_out : Uint256):
    alloc_locals

    let (local swap_fee : Ratio, _, _) = Register.get_pool_info()
    let (local a_balance : Uint256) = get_ERC20_balance(erc20_address_in)
    let (local a_weight : Ratio) = Register.get_token_weight(erc20_address_in)
    let (local b_balance : Uint256) = get_ERC20_balance(erc20_address_out)
    let (local b_weight : Ratio) = Register.get_token_weight(erc20_address_out)

    let (local ratio_out : Ratio) = Balancer_Math.get_out_given_in(
        amount_in, a_balance, a_weight, b_balance, b_weight, swap_fee)

    let (local amount_out : Uint256, _) = uint256_unsigned_div_rem(ratio_out.n, ratio_out.d)

    return (amount_out)
end

@view
func view_proportional_deposits_given_pool_out{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_out : Uint256) -> (list_len : felt, list : TokenAndAmount*):
    alloc_locals

    let (local total_pool_supply : Uint256) = totalSupply()
    local pool_supply_ratio : Ratio = Ratio(pool_amount_out, total_pool_supply)

    # build list of tokens and current balances
    let (local num_tokens_in_pool) = Register.get_num_tokens()
    let (local token_arr : TokenAndAmount*) = alloc()

    let (local token_list_len : felt,
        local token_list : TokenAndAmount*) = _recursive_build_list_of_tokens_and_balances(
        num_tokens_in_pool, 0, token_arr)

    let (local list_len : felt,
        list : TokenAndAmount*) = Balancer_Math.get_proportional_deposits_given_pool_out(
        pool_supply_ratio, token_list_len, token_list)

    return (list_len, list)
end

@view
func view_proportional_withdraw_given_pool_in{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_amount_in : Uint256) -> (list_len : felt, list : TokenAndAmount*):
    alloc_locals

    let (local total_pool_supply : Uint256) = totalSupply()
    let (local exit_fee : Ratio) = Register.get_exit_fee()

    # build list of tokens and current balances
    let (local num_tokens_in_pool) = Register.get_num_tokens()
    let (local token_arr : TokenAndAmount*) = alloc()

    let (local token_list_len : felt,
        local token_list : TokenAndAmount*) = _recursive_build_list_of_tokens_and_balances(
        num_tokens_in_pool, 0, token_arr)

    let (local list_len : felt,
        list : TokenAndAmount*) = Balancer_Math.get_proportional_withdraw_given_pool_in(
        total_pool_supply, pool_amount_in, exit_fee, token_list_len, token_list)

    return (list_len, list)
end

# recursion helper
func _recursive_build_list_of_tokens_and_balances{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        num_tokens_remaining : felt, output_arr_len : felt, output_arr : TokenAndAmount*) -> (
        output_list_len : felt, output_list : TokenAndAmount*):
    alloc_locals

    # needed for dereferencing struct
    let (__fp__, _) = get_fp_and_pc()

    if num_tokens_remaining == 0:
        return (output_arr_len, output_arr)
    end

    let (local erc : felt) = Register.get_approved_erc_from_index(output_arr_len)
    let (local balance : Uint256) = get_ERC20_balance(erc)

    # assert used for assignment
    assert output_arr[output_arr_len] = TokenAndAmount(erc, balance)

    let (local output_list_len : felt,
        local output_list : TokenAndAmount*) = _recursive_build_list_of_tokens_and_balances(
        num_tokens_remaining - 1, output_arr_len + 1, output_arr)

    return (output_list_len, output_list)
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
    let (approved : felt) = Register.is_erc20_approved(erc20_address)
    return (approved)
end

@view
func get_token_weight{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        erc20_address : felt) -> (approved : Ratio):
    alloc_locals
    let (weight : Ratio) = Register.get_token_weight(erc20_address)
    return (weight)
end

@view
func get_pool_into{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        erc20_address : felt) -> (swap_fee : Ratio, exit_fee : Ratio, total_weight : Ratio):
    alloc_locals
    let (s_fee : Ratio, e_fee : Ratio, t_w : Ratio) = Register.get_pool_info()
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
    let (name) = ERC20.name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC20.symbol()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        totalSupply : Uint256):
    let (totalSupply : Uint256) = ERC20.total_supply()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        decimals : felt):
    let (decimals) = ERC20.decimals()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (balance : Uint256):
    let (balance : Uint256) = ERC20.balance_of(account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt) -> (remaining : Uint256):
    let (remaining : Uint256) = ERC20.allowance(owner, spender)
    return (remaining)
end

#
# Externals
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256) -> (success : felt):
    ERC20.transfer(recipient, amount)
    return (TRUE)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    ERC20.transfer_from(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256) -> (success : felt):
    ERC20.approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, added_value : Uint256) -> (success : felt):
    ERC20.increase_allowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, subtracted_value : Uint256) -> (success : felt):
    ERC20.decrease_allowance(spender, subtracted_value)
    return (TRUE)
end

func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, amount : Uint256) -> (success : felt):
    ERC20._mint(to, amount)
    return (TRUE)
end

func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, amount : Uint256) -> (success : felt):
    ERC20._burn(account, amount)
    return (TRUE)
end
