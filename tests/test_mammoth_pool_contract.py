import pytest
import math

ERC20_DIGIT = 1000000000
INITIAL_DEPOSIT = 100 * ERC20_DIGIT


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
    simulated_profit = 10 * ERC20_DIGIT

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
    total_staked = await pool_contract.get_total_staked().call()
    assert total_staked.result == (INITIAL_DEPOSIT,)

    # total accrued rewards check
    S = await pool_contract.get_S().call()
    assert S.result == (0,)

    # check user balance
    user_balance = await pool_contract.get_user_balance(user, erc20_address).call()
    assert user_balance.result == (INITIAL_DEPOSIT,)

    # check lp tokens were minted that represent same amount as initial deposit
    user_lp_balance = await lp_token_contract.balance_of(user).call()
    assert user_lp_balance.result[0] == (INITIAL_DEPOSIT, 0)

    '''
    # increase pool contract erc20 balance (simulates profit from trading)
    await erc20_contract.mint(pool_contract.contract_address, simulated_profit).invoke()
    contract_erc20_balance = await erc20_contract.balance_of(
        pool_contract.contract_address
    ).call()

    assert contract_erc20_balance.result == (INITIAL_DEPOSIT + simulated_profit,)

    # distribute profits
    await proxy_contract.call_distribute(erc20_address, simulated_profit).invoke()

    # check the reward sum function is correct
    S = await pool_contract.get_S().call()
    assert S.result == (
        math.floor(((simulated_profit * erc20_rounded_decimal) / INITIAL_DEPOSIT)),
    )  # round down because of felt division in cairo

    # withdraw full amount
    await proxy_contract.mammoth_withdraw(
        initial_withdrawal, user, erc20_address
    ).invoke()

    # new total stake
    total_staked = await pool_contract.get_total_staked().call()
    assert total_staked.result == (0,)

    contract_erc20_balance = await erc20_contract.balance_of(user).call()
    assert contract_erc20_balance.result == (
        (mint_amount - INITIAL_DEPOSIT) + initial_withdrawal + simulated_profit,
    )

    """
    '''
