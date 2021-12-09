import pytest
import math

from .conftest import MINT_AMOUNT

ERC20_DIGIT = 1000000000  # we pay out rewards per this amount
INITIAL_DEPOSIT = 100 * ERC20_DIGIT
WITHDRAW_AMOUNT = INITIAL_DEPOSIT
SIMULATED_PROFIT = 10 * ERC20_DIGIT


@pytest.mark.asyncio
async def test_set_token_address(
    signer_factory, account_factory, proxy_factory, lp_token_factory
):
    signer = signer_factory
    user_account, _ = account_factory
    proxy_contract, proxy_address = proxy_factory
    _, lp_address = lp_token_factory

    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="set_token_contract_address",
        calldata=[lp_address],
    )

    stored_token = await proxy_contract.get_token_address().call()
    assert stored_token.result == (lp_address,)


@pytest.mark.asyncio
async def test_set_pool_address(
    signer_factory, account_factory, proxy_factory, pool_factory
):
    signer = signer_factory
    user_account, _ = account_factory
    proxy_contract, proxy_address = proxy_factory
    _, pool_address = pool_factory

    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="set_pool_contract_address",
        calldata=[pool_address],
    )

    # check pool address properly stored
    stored_pool = await proxy_contract.get_pool_address().call()
    assert stored_pool.result == (pool_address,)


@pytest.mark.asyncio
async def test_approve_erc20(
    signer_factory, account_factory, proxy_factory, erc20_factory
):
    signer = signer_factory
    user_account, _ = account_factory
    proxy_contract, proxy_address = proxy_factory
    _, erc20_address = erc20_factory

    # check value before approval
    approval = await proxy_contract.is_erc20_approved(erc20_address).call()
    assert approval.result[0] != 1

    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="add_approved_erc20",
        calldata=[erc20_address],
    )

    # check value after approval
    approval = await proxy_contract.is_erc20_approved(erc20_address).call()
    assert approval.result[0] == 1


@pytest.mark.asyncio
async def test_approve_pool(
    signer_factory, account_factory, pool_factory, erc20_factory
):
    signer = signer_factory
    user_account, user = account_factory
    erc20_contract, erc20_address = erc20_factory
    _, pool_address = pool_factory

    # approve ERC20 to be deposited to POOL
    await signer.send_transaction(
        account=user_account,
        to=erc20_address,
        selector_name="approve",
        # extra 0 because of Uint256
        calldata=[pool_address, INITIAL_DEPOSIT, 0],
    )

    # check that correct amount is allowed
    pool_allowance = await erc20_contract.allowance(user, pool_address).call()
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
    pool_contract, _ = pool_factory
    lp_token_contract, _ = lp_token_factory
    _, proxy_address = proxy_factory
    _, erc20_address = erc20_factory

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="mammoth_deposit",
        calldata=[INITIAL_DEPOSIT, user, erc20_address],
    )

    # new total stake
    total_staked = await pool_contract.get_total_staked(erc20_address).call()
    assert total_staked.result == (INITIAL_DEPOSIT,)

    # total accrued rewards check
    S = await pool_contract.get_S(erc20_address).call()
    assert S.result == (0,)

    # check user balance
    user_balance = await pool_contract.get_user_balance(user, erc20_address).call()
    assert user_balance.result == (INITIAL_DEPOSIT,)

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
    pool_contract, _ = pool_factory
    _, proxy_address = proxy_factory
    _, erc20_address = erc20_factory

    # distribute rewards
    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="mammoth_distribute",
        # erc20_address says which rewards to distribute
        calldata=[erc20_address, SIMULATED_PROFIT],
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
    pool_contract, _ = pool_factory
    lp_token_contract, _ = lp_token_factory
    _, proxy_address = proxy_factory
    erc20_contract, erc20_address = erc20_factory

    # deposit initial amount
    await signer.send_transaction(
        account=user_account,
        to=proxy_address,
        selector_name="mammoth_withdraw",
        calldata=[WITHDRAW_AMOUNT, user, erc20_address],
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
