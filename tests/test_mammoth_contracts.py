import pytest
import math
from hypothesis import given, strategies as st, settings

from ..contracts.lib.openzeppelin.tests.utils import to_uint, from_uint
from .conftest import DECIMALS


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
    _, pool_address = pool_factory
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
    pool_contract, pool_address = pool_factory
    tusdc_contract, tusdc_address = tusdc_factory
    fc_contract, fc_address = fc_factory
    teeth_contract, teeth_address = teeth_factory

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
            user_address,
            pool_address,
            *swap_fee[0],
            *swap_fee[1],
            *exit_fee[0],
            *exit_fee[1],
            3,
            *erc_array_input,
        ],
    )

    stored_token = await router_contract.is_pool_approved(pool_address).call()
    assert stored_token.result == (1,)

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
    pool_contract, _ = pool_factory
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
    pool_contract, pool_address = pool_factory
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
    pool_contract, pool_address = pool_factory
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
async def test_mammoth_deposit(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    fc_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_contract, pool_address = pool_factory
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
        selector_name="mammoth_deposit",
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


# @given(
#    x=st.integers(min_value=1, max_value=999),
# )
# @settings(deadline=None)
@pytest.mark.asyncio
async def test_mammoth_withdraw(
    signer_factory,
    account_factory,
    router_factory,
    pool_factory,
    tusdc_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_contract, pool_address = pool_factory
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
        selector_name="mammoth_withdraw",
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
    pool_contract, pool_address = pool_factory
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
