import pytest
import math
from hypothesis import given, strategies as st, settings
from starkware.starknet.testing.contract import StarknetContract

from .oz_utils import to_uint, from_uint, str_to_felt
from .conftest import DECIMALS
\

@pytest.mark.asyncio
async def test_deploy_pool(signer_factory, starknet_factory, account_factory, router_factory, pool_factory, class_hash_factory):
    signer = signer_factory
    starknet = starknet_factory
    user_account, user = account_factory
    router, router_address = router_factory
    proxy_hash, pool_hash, _, pool_abi = class_hash_factory

    # set proxy_hash
    proxy_hash_return = await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="set_proxy_class_hash",
        calldata=[proxy_hash],
    )

    assert proxy_hash_return.result[0] == [1]

    # set pool_hash
    pool_hash_return = await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="define_pool_type_class_hash",
        calldata=[str_to_felt("DEFAULTv0"), pool_hash],
    )

    assert pool_hash_return.result[0] == [1]

    deploy_pool_return = await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="deploy_pool",
        calldata=[str_to_felt("DEFAULTv0"), user],
    )

    pool_address = deploy_pool_return.result
    pool_factory['pool_address'] = pool_address.response[0]
    pool_factory['pool_contract'] = StarknetContract(starknet.state, pool_abi, pool_address.response[0], deploy_pool_return)


@pytest.mark.asyncio
async def test_approve_pool_for_transfer(
    signer_factory,
    account_factory,
    tusdc_factory,
    fc_factory,
    teeth_factory,
    pool_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_address = pool_factory['pool_address']
    tusdc, tusdc_address = tusdc_factory
    fc, fc_address = fc_factory
    teeth, teeth_address = teeth_factory
    list_of_erc_address = [tusdc_address, fc_address, teeth_address]
    list_of_erc_contract = [tusdc, fc, teeth]

    for erc_address, erc_contract in zip(list_of_erc_address, list_of_erc_contract):
        # approve ERC20 to be deposited to POOL
        await signer.send_transaction(
            account=user_account,
            to=erc_address,
            selector_name="approve",
            # extra 0 because of Uint256
            calldata=[pool_address, 800000 * DECIMALS, 0],
        )

        # check that correct amount is allowed
        pool_allowance = await erc_contract.allowance(user, pool_address).call()
        assert pool_allowance.result == ((800000 * DECIMALS, 0),)


@pytest.mark.asyncio
async def test_create_pool(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    tusdc_factory,
    fc_factory,
    teeth_factory,
):
    signer = signer_factory
    user_account, user_address = account_factory
    router_contract, router_address = router_factory
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    tusdc_contract, tusdc_address = tusdc_factory
    fc_contract, fc_address = fc_factory
    teeth_contract, teeth_address = teeth_factory

    print(dir(pool_factory['pool_contract']))

    swap_fee = [to_uint(2), to_uint(1000)]  # .02%
    exit_fee = [to_uint(2), to_uint(1000)]  # .02%
    # weight of 1/3 represented as 1, 0, 3, 0
    erc_array_input = (
        tusdc_address,
        1,  # weight
        0,
        3,
        0,
        (3000 * DECIMALS),  # initial liquidity amount
        0,
        fc_address,
        1,  # weight
        0,
        3,
        0,
        (1 * DECIMALS),  # initial liquidity amount
        0,
        teeth_address,
        1,  # weight
        0,
        3,
        0,
        (2 * DECIMALS),  # initial liquidity amount
        0
    )

    await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="create_pool",
        calldata=[
            pool_address,
            str_to_felt("MAMMOTH_LP"),  # name
            str_to_felt("MLP"),  # symbol
            18,  # decimals
            user_address,
            *swap_fee[0],
            *swap_fee[1],
            *exit_fee[0],
            *exit_fee[1],
            3,
            *erc_array_input,
        ],
    )

    #stored_token = await router_contract.is_pool_approved(pool_address).call()
    #assert stored_token.result == (1,)

    erc_approval = await pool_contract.is_ERC20_approved(tusdc_address).call()
    assert erc_approval.result == (1,)

    erc_approval = await pool_contract.is_ERC20_approved(fc_address).call()
    assert erc_approval.result == (1,)

    erc_approval = await pool_contract.is_ERC20_approved(teeth_address).call()
    assert erc_approval.result == (1,)

    user_lp_balance = await pool_contract.balanceOf(user_address).call()
    assert user_lp_balance.result == ((3000 * DECIMALS, 0),)

    pool_tusdc_balance = await tusdc_contract.balanceOf(pool_address).call()
    assert pool_tusdc_balance.result == ((3000 * DECIMALS, 0),)

    pool_fc_balance = await fc_contract.balanceOf(pool_address).call()
    assert pool_fc_balance.result == ((1 * DECIMALS, 0),)

    pool_teeth_balance = await teeth_contract.balanceOf(pool_address).call()
    assert pool_teeth_balance.result == ((2 * DECIMALS, 0),)

    # ADD MORE TESTS TO MAKE SURE POOL INITIALIZED PROPERLY


@pytest.mark.asyncio
async def test_view_single_out_given_pool_in(
    pool_factory, tusdc_factory, balancer_factory
):
    pool_contract = pool_factory['pool_contract']
    _, tusdc_address = tusdc_factory
    balancer, _ = balancer_factory

    tusdc_out = await pool_contract.view_single_out_given_pool_in(
        to_uint(1 * DECIMALS), tusdc_address
    ).call()

    desired = await balancer.get_single_out_given_pool_in(
        to_uint(1 * DECIMALS),
        to_uint(9 * DECIMALS),
        to_uint(10 * DECIMALS),
        (to_uint(1), to_uint(3)),
        (to_uint(1), to_uint(1)),
        (to_uint(2), to_uint(1000)),
        (to_uint(2), to_uint(1000)),
    ).call()

    assert (
        from_uint(tusdc_out.result[0])
        - from_uint(desired.result[0][0]) / from_uint(desired.result[0][1])
        < 0.000005
    )


@pytest.mark.asyncio
async def test_view_pool_minted_given_single_in(
    pool_factory, tusdc_factory, balancer_factory
):
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    _, tusdc_address = tusdc_factory
    balancer, _ = balancer_factory

    lp_out = await pool_contract.view_pool_minted_given_single_in(
        to_uint(1 * DECIMALS), tusdc_address
    ).call()

    desired = await balancer.get_pool_minted_given_single_in(
        to_uint(1 * DECIMALS),
        to_uint(9 * DECIMALS),
        to_uint(10 * DECIMALS),
        (to_uint(1), to_uint(3)),
        (to_uint(1), to_uint(1)),
        (to_uint(2), to_uint(1000)),
    ).call()

    assert (
        from_uint(lp_out.result[0])
        - from_uint(desired.result[0][0]) / from_uint(desired.result[0][1])
        < 0.000005
    )


@pytest.mark.asyncio
async def test_view_out_given_in(
    pool_factory, tusdc_factory, fc_factory, balancer_factory
):
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    _, tusdc_address = tusdc_factory
    _, fc_address = fc_factory
    balancer, _ = balancer_factory

    amount_out = await pool_contract.view_out_given_in(
        to_uint(1 * DECIMALS), tusdc_address, fc_address
    ).call()

    desired = await balancer.get_out_given_in(
        to_uint(1 * DECIMALS),
        to_uint(9 * DECIMALS),
        (to_uint(1), to_uint(3)),
        to_uint(9 * DECIMALS),
        (to_uint(1), to_uint(3)),
        (to_uint(2), to_uint(1000)),
    ).call()

    assert (
        from_uint(amount_out.result[0])
        - from_uint(desired.result[0][0]) / from_uint(desired.result[0][1])
        < 0.000005
    )


# @given(
#    x=st.integers(min_value=1, max_value=999),
# )
# @settings(deadline=None)
@pytest.mark.asyncio
async def test_mammoth_deposit_single_asset(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    fc_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    _, router_address = router_factory
    _, fc_address = fc_factory

    await signer.send_transaction(
        account=user_account,
        to=fc_address,
        selector_name="mint",
        calldata=[user, *to_uint(4 * DECIMALS)],
    )

    initial_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    initial_user_lp = await pool_contract.balanceOf(user).call()
    lp_to_mint = await pool_contract.view_pool_minted_given_single_in(
        to_uint(4 * DECIMALS), fc_address
    ).call()

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="mammoth_deposit_single_asset",
        calldata=[*to_uint(4 * DECIMALS), user, pool_address, fc_address],
    )

    # new erc balance
    new_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    assert (
        from_uint(new_balance.result[0]) - from_uint(initial_balance.result[0])
        == 4 * DECIMALS
    )

    # new lp balance
    new_user_lp_balance = await pool_contract.balanceOf(user).call()
    assert from_uint(new_user_lp_balance.result[0]) - from_uint(
        initial_user_lp.result[0]
    ) == from_uint(lp_to_mint.result[0])


@pytest.mark.asyncio
async def test_mammoth_proportional_deposit(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    fc_factory,
    tusdc_factory,
    teeth_factory
):
    signer = signer_factory
    user_account, user = account_factory
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    _, router_address = router_factory
    _, fc_address = fc_factory
    _, tusdc_address = tusdc_factory
    _, teeth_address = teeth_factory

    fc_initial_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    tusdc_initial_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    teeth_initial_balance = await pool_contract.get_ERC20_balance(teeth_address).call()
    total_lp_supply = await pool_contract.totalSupply().call()
    initial_user_lp = await pool_contract.balanceOf(user).call()

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="mammoth_proportional_deposit",
        calldata=[*to_uint(4 * DECIMALS), user, pool_address],
    )

    # new fc balance
    fc_new_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    assert from_uint(fc_new_balance.result[0]) - from_uint(fc_initial_balance.result[0]) - (
        ((4 * DECIMALS) / (from_uint(total_lp_supply.result[0]))) * from_uint(fc_initial_balance.result[0])) < 5 / (10 ** 5)

    tusdc_new_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    assert from_uint(tusdc_new_balance.result[0]) - from_uint(tusdc_initial_balance.result[0]) - (
        ((4 * DECIMALS) / (from_uint(total_lp_supply.result[0]))) * from_uint(tusdc_initial_balance.result[0])) < 5 / (10 ** 5)

    # new fc balance
    teeth_new_balance = await pool_contract.get_ERC20_balance(teeth_address).call()
    assert from_uint(teeth_new_balance.result[0]) - from_uint(teeth_initial_balance.result[0]) - (
        ((4 * DECIMALS) / (from_uint(total_lp_supply.result[0]))) * from_uint(teeth_initial_balance.result[0])) < 5 / (10 ** 5)

    # new lp balance
    new_user_lp_balance = await pool_contract.balanceOf(user).call()
    assert from_uint(new_user_lp_balance.result[0]) - from_uint(
        initial_user_lp.result[0]
    ) == 4 * DECIMALS


# @given(
#    x=st.integers(min_value=1, max_value=999),
# )
# @settings(deadline=None)
@pytest.mark.asyncio
async def test_mammoth_withdraw_single_asset(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    tusdc_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    _, router_address = router_factory
    _, tusdc_address = tusdc_factory

    initial_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    initial_user_lp = await pool_contract.balanceOf(user).call()
    tusdc_to_withdraw = await pool_contract.view_single_out_given_pool_in(
        to_uint(5 * DECIMALS), tusdc_address
    ).call()

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="mammoth_withdraw_single_asset",
        calldata=[*to_uint(5 * DECIMALS), user, pool_address, tusdc_address],
    )

    # tusdc balance
    new_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    assert from_uint(initial_balance.result[0]) - from_uint(
        new_balance.result[0]
    ) == from_uint(tusdc_to_withdraw.result[0])

    # check lp tokens were minted that represent same amount as initial deposit
    new_user_lp_balance = await pool_contract.balanceOf(user).call()
    assert (
        from_uint(initial_user_lp.result[0]) -
        from_uint(new_user_lp_balance.result[0])
        == 5 * DECIMALS
    )


@pytest.mark.asyncio
async def test_mammoth_proportional_withdraw(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    fc_factory,
    tusdc_factory,
    teeth_factory
):
    signer = signer_factory
    user_account, user = account_factory
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    _, router_address = router_factory
    _, fc_address = fc_factory
    _, tusdc_address = tusdc_factory
    _, teeth_address = teeth_factory

    fc_initial_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    tusdc_initial_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    teeth_initial_balance = await pool_contract.get_ERC20_balance(teeth_address).call()
    total_lp_supply = await pool_contract.totalSupply().call()
    initial_user_lp = await pool_contract.balanceOf(user).call()

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="mammoth_proportional_withdraw",
        calldata=[*to_uint(4 * DECIMALS), user, pool_address],
    )

    # new fc balance
    fc_new_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    assert from_uint(fc_new_balance.result[0]) - from_uint(fc_initial_balance.result[0]) - (
        (((4 * DECIMALS) * (2 * 4 * DECIMALS / 1000)) / (from_uint(total_lp_supply.result[0]))) * from_uint(fc_initial_balance.result[0])) < 5 / (10 ** 5)

    tusdc_new_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    assert from_uint(tusdc_new_balance.result[0]) - from_uint(tusdc_initial_balance.result[0]) - (
        (((4 * DECIMALS) * (2 * 4 * DECIMALS / 1000)) / (from_uint(total_lp_supply.result[0]))) * from_uint(tusdc_initial_balance.result[0])) < 5 / (10 ** 5)

    # new fc balance
    teeth_new_balance = await pool_contract.get_ERC20_balance(teeth_address).call()
    assert from_uint(teeth_new_balance.result[0]) - from_uint(teeth_initial_balance.result[0]) - (
        (((4 * DECIMALS) * (2 * 4 * DECIMALS / 1000)) / (from_uint(total_lp_supply.result[0]))) * from_uint(teeth_initial_balance.result[0])) < 5 / (10 ** 5)

    # new lp balance
    new_user_lp_balance = await pool_contract.balanceOf(user).call()
    assert abs(from_uint(new_user_lp_balance.result[0]) - from_uint(
        initial_user_lp.result[0]
    )) == 4 * DECIMALS


# @given(
#    x=st.integers(min_value=1, max_value=999),
# )
# @settings(deadline=None)
@pytest.mark.asyncio
async def test_mammoth_swap(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    tusdc_factory,
    fc_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_address = pool_factory['pool_address']
    pool_contract = pool_factory['pool_contract']
    _, router_address = router_factory
    _, tusdc_address = tusdc_factory
    _, fc_address = fc_factory

    await signer.send_transaction(
        account=user_account,
        to=tusdc_address,
        selector_name="mint",
        calldata=[user, *to_uint(10 * DECIMALS)],
    )
    initial_fc_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    initial_tusdc_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    fc_for_tusdc = await pool_contract.view_out_given_in(
        to_uint(7 * DECIMALS), tusdc_address, fc_address
    ).call()

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=router_address,
        selector_name="mammoth_swap",
        calldata=[
            *to_uint(7 * DECIMALS),
            user,
            pool_address,
            tusdc_address,
            fc_address,
        ],
    )

    # new usdc balance
    new_tusdc_balance = await pool_contract.get_ERC20_balance(tusdc_address).call()
    assert (
        from_uint(new_tusdc_balance.result[0])
        - from_uint(initial_tusdc_balance.result[0])
        == 7 * DECIMALS
    )

    # new fc balance
    new_fc_balance = await pool_contract.get_ERC20_balance(fc_address).call()
    assert from_uint(initial_fc_balance.result[0]) - from_uint(
        new_fc_balance.result[0]
    ) == from_uint(fc_for_tusdc.result[0])
