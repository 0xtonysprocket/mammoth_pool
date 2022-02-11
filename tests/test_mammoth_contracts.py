import pytest
import math

from .conftest import MINT_AMOUNT

ERC20_DIGIT = 1000000000  # we pay out rewards per this amount
INITIAL_DEPOSIT = 100 * ERC20_DIGIT
WITHDRAW_AMOUNT = INITIAL_DEPOSIT
SIMULATED_PROFIT = 10 * ERC20_DIGIT


@pytest.mark.asyncio
async def test_create_pool(
    signer_factory, account_factory, proxy_factory, pool_factory, lp_token_factory
):
    signer = signer_factory
    user_account, _ = account_factory
    proxy_contract, proxy_address = proxy_factory
    _, pool_address = pool_factory
    _, lp_address = lp_token_factory

    swap_fee = (2, 1000)  # .02%
    exit_fee = (2, 1000)  # .02%

    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="create_pool",
        calldata=[lp_address, pool_address, *swap_fee, *exit_fee],
    )

    stored_token = await proxy_contract.get_token_address_for_pool(pool_address).call()
    print(stored_token)
    assert stored_token.result == (lp_address,)

    stored_token = await proxy_contract.get_swap_fee_for_pool(pool_address).call()
    assert stored_token.result == (swap_fee,)

    stored_token = await proxy_contract.get_exit_fee_for_pool(pool_address).call()
    assert stored_token.result == (exit_fee,)


@pytest.mark.asyncio
async def test_approve_erc20_for_pool(
    signer_factory,
    account_factory,
    proxy_factory,
    tusdc_factory,
    fc_factory,
    teeth_factory,
    pool_factory,
):
    signer = signer_factory
    user_account, _ = account_factory
    proxy_contract, proxy_address = proxy_factory
    _, pool_address = pool_factory
    _, tusdc = tusdc_factory
    _, fc = fc_factory
    _, teeth = teeth_factory
    list_of_erc = [tusdc, fc, teeth]

    weight = (1, 3)  # .33

    for erc in list_of_erc:
        # check value before approval
        approval = await proxy_contract.is_erc20_approved(pool_address, erc).call()
        assert approval.result[0] != 1

        await signer.send_transaction(
            account=user_account,
            to=proxy_address,
            selector_name="add_approved_erc20_for_pool",
            calldata=[pool_address, erc, *weight],
        )

        # check value after approval
        approval = await proxy_contract.is_erc20_approved(pool_address, erc).call()
        assert approval.result[0] == 1

        stored_token = await proxy_contract.get_weight_for_token(
            pool_address, erc
        ).call()
        assert stored_token.result == (weight,)


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
            calldata=[pool_address, INITIAL_DEPOSIT, 0],
        )

        # check that correct amount is allowed
        pool_allowance = await erc_contract.allowance(user, pool_address).call()
        assert pool_allowance.result == ((INITIAL_DEPOSIT, 0),)


@pytest.mark.asyncio
async def test_view_single_out_given_pool_in(
    proxy_factory, pool_factory, tusdc_factory, balancer_factory
):
    proxy_contract, _ = proxy_factory
    _, pool_address = pool_factory
    _, tusdc_address = tusdc_factory
    balancer, _ = balancer_factory

    tusdc_out = await proxy_contract.view_single_out_given_pool_in(
        100, pool_address, tusdc_address
    ).call()

    desired = await balancer.get_single_out_given_pool_in(
        100, 999, (1000, 0), (1, 3), (1, 1), (2, 1000), (2, 1000)
    ).call()

    print(tusdc_out)
    print(desired)

    assert tusdc_out.result - desired.result < 0.005


"""
@pytest.mark.asyncio
async def test_mammoth_deposit(
    signer_factory,
    account_factory,
    proxy_factory,
    pool_factory,
    erc20_factory,
    lp_token_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_contract, pool_address = pool_factory
    lp_token_contract, _ = lp_token_factory
    _, proxy_address = proxy_factory
    _, erc20_address = erc20_factory

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="mammoth_deposit",
        calldata=[INITIAL_DEPOSIT, user, pool_address, erc20_address],
    )

    # new total stake
    total_staked = await pool_contract.get_total_staked(erc20_address).call()
    assert total_staked.result == (INITIAL_DEPOSIT,)

    # check lp tokens were minted that represent same amount as initial deposit
    user_lp_balance = await lp_token_contract.balance_of(user).call()
    assert user_lp_balance.result[0] == (INITIAL_DEPOSIT, 0)


@pytest.mark.asyncio
async def test_manual_increase_to_simulate_profit(erc20_factory, pool_factory):
    erc20_contract, _ = erc20_factory
    _, pool_address = pool_factory

    # increase pool contract erc20 balance (simulates profit from trading)
    await erc20_contract._mint(pool_address, (SIMULATED_PROFIT, 0)).invoke()
    contract_erc20_balance = await erc20_contract.balanceOf(pool_address).call()

    assert contract_erc20_balance.result[0] == (INITIAL_DEPOSIT + SIMULATED_PROFIT, 0)


@pytest.mark.asyncio
async def test_mammoth_distribute(
    signer_factory, account_factory, proxy_factory, erc20_factory, pool_factory
):

    signer = signer_factory
    user_account, _ = account_factory
    pool_contract, pool_address = pool_factory
    _, proxy_address = proxy_factory
    _, erc20_address = erc20_factory

    # distribute rewards
    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="mammoth_distribute",
        # erc20_address says which rewards to distribute
        calldata=[pool_address, erc20_address, SIMULATED_PROFIT],
    )

    # check the reward sum function is correct
    S = await pool_contract.get_S(erc20_address).call()
    assert S.result == (
        math.floor(((SIMULATED_PROFIT * ERC20_DIGIT) / INITIAL_DEPOSIT)),
    )  # round down because of felt division in cairo


@pytest.mark.asyncio
async def test_mammoth_withdraw(
    signer_factory,
    account_factory,
    proxy_factory,
    pool_factory,
    erc20_factory,
    lp_token_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    pool_contract, pool_address = pool_factory
    lp_token_contract, _ = lp_token_factory
    _, proxy_address = proxy_factory
    erc20_contract, erc20_address = erc20_factory

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="mammoth_withdraw",
        calldata=[WITHDRAW_AMOUNT, user, pool_address, erc20_address],
    )

    # new total stake
    total_staked = await pool_contract.get_total_staked(erc20_address).call()
    assert total_staked.result == (INITIAL_DEPOSIT - WITHDRAW_AMOUNT,)

    # check that the user withdrew initial stake plus their allocated profits
    contract_erc20_balance = await erc20_contract.balanceOf(user).call()
    assert contract_erc20_balance.result[0] == (MINT_AMOUNT + SIMULATED_PROFIT, 0)

    # check that the LP contract burned the corresponding LP tokens
    user_lp_balance = await lp_token_contract.balance_of(user).call()
    assert user_lp_balance.result[0] == (0, 0)
"""
