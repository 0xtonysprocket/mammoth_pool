import os
import pytest
import math
from decouple import config

from starkware.starknet.testing.starknet import Starknet

POOL_CONTRACT = os.path.join(
    "/Users/andrewnoel/Cairo/mammoth_pool/contracts/mammoth_pool.cairo"
)

ERC20_CONTRACT = os.path.join(
    "/Users/andrewnoel/Cairo/mammoth_pool/contracts/ERC20.cairo"
)


# TODO figure out what my address is when sending the transactions in this environment


@pytest.mark.asyncio
async def test_deposit():
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # define variables
    ERC_NAME = 12
    ERC_SYMBOL = 567
    user = 123

    number_of_deposits = 0
    erc20_rounded_decimal = 1000000000
    initial_deposit = 100 * erc20_rounded_decimal
    initial_withdrawal = initial_deposit
    simulated_profit = 10 * erc20_rounded_decimal
    mint_amount = 1000 * erc20_rounded_decimal

    # Deploy the contract.
    pool_contract = await starknet.deploy(
        source=POOL_CONTRACT,
    )

    erc20_contract = await starknet.deploy(
        source=ERC20_CONTRACT,
        constructor_calldata=[ERC_NAME, ERC_SYMBOL, user, mint_amount],
    )

    # define contract variables
    erc20_address = erc20_contract.contract_address

    # NEED TO APPROVE CONTRACT TO TRANSFER FOR THIS TO WORK
    # test deposit
    await pool_contract.proxy_deposit(initial_deposit, user, erc20_address).invoke()
    number_of_deposits += 1

    # new total stake
    total_staked = await pool_contract.get_total_staked().call()
    assert total_staked.result == (initial_deposit,)

    # total accrued rewards check
    S = await pool_contract.get_S().call()
    assert S.result == (0,)

    # check user balance
    user_balance = await pool_contract.get_user_balance(user, erc20_address).call()
    assert user_balance.result == (initial_deposit,)

    # increase pool contract erc20 balance (simulates profit from trading)
    await erc20_contract.mint(pool_contract.contract_address, simulated_profit).invoke()
    contract_erc20_balance = await erc20_contract.balance_of(
        pool_contract.contract_address
    ).call()

    assert contract_erc20_balance.result == (initial_deposit + simulated_profit,)

    # distribute profits
    await pool_contract.proxy_distribute(erc20_address, simulated_profit).invoke()

    # check the reward sum function is correct
    S = await pool_contract.get_S().call()
    assert S.result == (
        math.floor(((simulated_profit * erc20_rounded_decimal) / initial_deposit)),
    )  # round down because of felt division in cairo

    # withdraw full amount
    await pool_contract.proxy_withdraw(initial_withdrawal, user, erc20_address).invoke()

    # new total stake
    total_staked = await pool_contract.get_total_staked().call()
    assert total_staked.result == (0,)

    contract_erc20_balance = await erc20_contract.balance_of(user).call()
    assert contract_erc20_balance.result == (
        (mint_amount - initial_deposit) + initial_withdrawal + simulated_profit,
    )
