# implements the following:
#
# ON POOL
# call_deposit
# call_withdraw

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.lib.openzeppelin.contracts.utils.constants import TRUE, FALSE

from contracts.lib.ratios.contracts.ratio import Ratio
from contracts.lib.Pool_registry_base import ApprovedERC20

@contract_interface
namespace IPoolContract:
    func deposit_single_asset(amount : Uint256, user_address : felt, erc20_address : felt) -> (
            success : felt):
    end

    func deposit_proportional_assets(pool_amount_out : Uint256, user_address : felt) -> (
            success : felt):
    end

    func withdraw_single_asset(amount : Uint256, address : felt, erc20_address : felt) -> (
            success : felt):
    end

    func withdraw_proportional_assets(pool_amount_in : Uint256, user_address : felt) -> (
            success : felt):
    end

    func swap(
            amount : Uint256, address : felt, erc20_address_in : felt,
            erc20_address_out : felt) -> (success : felt):
    end

    func get_ERC20_balance(erc20_address : felt) -> (res : Uint256):
    end
end

@contract_interface
namespace IPoolRegister:
    func initialize_pool(
            caller_address : felt, s_fee : Ratio, e_fee : Ratio, erc_list_len : felt,
            erc_list : ApprovedERC20*) -> (bool : felt, lp_amount : Uint256):
    end
end

# store the address of the pool contract
@storage_var
func approved_pool_address(pool_address : felt) -> (bool : felt):
end

namespace Router:
    func call_deposit_single_asset{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount : Uint256, user_address : felt, pool_address : felt, erc20_address : felt) -> (
            success : felt):
        alloc_locals
        let (local success : felt) = IPoolContract.deposit_single_asset(
            contract_address=pool_address,
            amount=amount,
            user_address=user_address,
            erc20_address=erc20_address)
        assert success = TRUE
        return (TRUE)
    end

    func call_deposit_proportional_assets{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_amount_out : Uint256, user_address : felt, pool_address : felt) -> (
            success : felt):
        alloc_locals
        let (local success : felt) = IPoolContract.deposit_proportional_assets(
            contract_address=pool_address,
            pool_amount_out=pool_amount_out,
            user_address=user_address)
        assert success = TRUE
        return (TRUE)
    end

    func call_withdraw_single_asset{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount : Uint256, user_address : felt, pool_address : felt, erc20_address : felt) -> (
            success : felt):
        alloc_locals
        let (local success : felt) = IPoolContract.withdraw_single_asset(
            contract_address=pool_address,
            amount=amount,
            address=user_address,
            erc20_address=erc20_address)
        assert success = TRUE
        return (TRUE)
    end

    func call_withdraw_proportional_assets{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_amount_in : Uint256, user_address : felt, pool_address : felt) -> (success : felt):
        alloc_locals
        let (local success : felt) = IPoolContract.withdraw_proportional_assets(
            contract_address=pool_address,
            pool_amount_in=pool_amount_in,
            user_address=user_address)
        assert success = TRUE
        return (TRUE)
    end

    func call_swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount : Uint256, address : felt, pool_address : felt, erc20_address_in : felt,
            erc20_address_out : felt) -> (success : felt):
        alloc_locals
        let (local success : felt) = IPoolContract.swap(
            contract_address=pool_address,
            amount=amount,
            address=address,
            erc20_address_in=erc20_address_in,
            erc20_address_out=erc20_address_out)
        assert success = TRUE
        return (TRUE)
    end

    func create_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            caller_address : felt, pool_address : felt, s_fee : Ratio, e_fee : Ratio,
            erc_list_len : felt, erc_list : ApprovedERC20*) -> (bool : felt, lp_amount : Uint256):
        alloc_locals
        approved_pool_address.write(pool_address, TRUE)
        let (local success : felt, local lp_amount : Uint256) = IPoolRegister.initialize_pool(
            contract_address=pool_address,
            caller_address=caller_address,
            s_fee=s_fee,
            e_fee=e_fee,
            erc_list_len=erc_list_len,
            erc_list=erc_list)
        assert success = TRUE
        return (TRUE, lp_amount)
    end

    func only_approved_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_address : felt):
        alloc_locals

        let (local approved : felt) = approved_pool_address.read(pool_address)
        assert approved = TRUE

        return ()
    end

    func pool_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            pool_address : felt) -> (bool : felt):
        alloc_locals
        let (local bool : felt) = approved_pool_address.read(pool_address)
        return (bool)
    end
end
