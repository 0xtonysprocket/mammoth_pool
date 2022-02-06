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
        calldata=[pool_address, lp_address, swap_fee, exit_fee],
    )

    stored_token = await proxy_contract.get_token_address_for_pool(pool_address).call()
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
    erc20_factory,
    erc20_factory_2,
    erc20_factory_3,
    pool_factory,
):
    signer = signer_factory
    user_account, _ = account_factory
    proxy_contract, proxy_address = proxy_factory
    _, pool_address = pool_factory
    _, erc20_address = erc20_factory
    _, erc20_address_2 = erc20_factory_2
    _, erc20_address_3 = erc20_factory_3
    list_of_erc = [erc20_address, erc20_address_2, erc20_address_3]

    weight = (1, 3)  # .33

    for erc in list_of_erc:
        # check value before approval
        approval = await proxy_contract.is_erc20_approved(
            pool_address, erc20_address
        ).call()
        assert approval.result[0] != 1

        await signer.send_transaction(
            account=user_account,
            to=proxy_address,
            selector_name="add_approved_erc20_for_pool",
            calldata=[pool_address, erc, weight],
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
    erc20_factory,
    erc20_factory_2,
    erc20_factory_3,
    pool_factory,
):
    signer = signer_factory
    user_account, user = account_factory
    _, pool_address = pool_factory
    erc20_contract, erc20_address = erc20_factory
    erc20_contract_2, erc20_address_2 = erc20_factory_2
    erc20_contract_3, erc20_address_3 = erc20_factory_3
    list_of_erc_address = [erc20_address, erc20_address_2, erc20_address_3]
    list_of_erc_contract = [erc20_contract, erc20_contract_2, erc20_contract_3]

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
