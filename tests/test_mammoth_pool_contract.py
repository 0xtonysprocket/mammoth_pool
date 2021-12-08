import os
import pytest
import math

from ..lib.Signer import Signer

from starkware.starknet.testing.starknet import Starknet

POOL_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/mammoth_pool.cairo"
)

PROXY_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/mammoth_proxy.cairo"
)

ERC20_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../lib/openzeppelin/contracts/token/ERC20.cairo"
)

ACCOUNT_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../lib/openzeppelin/contracts/Account.cairo"
)


def uint(a):
    return (int(a), 0)


@pytest.mark.asyncio
async def test_deposit():
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # define variables and convert to hex
    ERC_NAME = int("TEST".encode().hex(), 16)
    ERC_SYMBOL = int("T".encode().hex(), 16)
    LP_NAME = int("TEST_LP".encode().hex(), 16)
    LP_SYMBOL = int("TLP".encode().hex(), 16)

    # create starknet signer
    signer = Signer(12345)

    number_of_deposits = 0
    erc20_rounded_decimal = 1000000000
    initial_deposit = 100 * erc20_rounded_decimal
    initial_withdrawal = initial_deposit
    simulated_profit = 10 * erc20_rounded_decimal
    mint_amount = uint(1000 * erc20_rounded_decimal)

    # Deploy the contract.
    user_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT, constructor_calldata=[signer.public_key]
    )

    # set user address to the user_account address
    user = user_account.contract_address

    proxy_contract = await starknet.deploy(
        source=PROXY_CONTRACT,
        constructor_calldata=[user],
    )

    pool_contract = await starknet.deploy(
        source=POOL_CONTRACT,
        constructor_calldata=[proxy_contract.contract_address],
    )

    erc20_contract = await starknet.deploy(
        source=ERC20_CONTRACT,
        constructor_calldata=[ERC_NAME, ERC_SYMBOL, user, mint_amount],
    )

    lp_token_contract = await starknet.deploy(
        source=ERC20_CONTRACT,
        constructor_calldata=[LP_NAME, LP_SYMBOL, user, uint(0)],
    )

    # define contract variables
    pool_address = pool_contract.contract_address
    erc20_address = erc20_contract.contract_address
    lp_address = lp_token_contract.contract_address

    await proxy_contract.set_token_contract_address(lp_address).invoke()
    await proxy_contract.set_pool_contract_address(pool_address).invoke()

    # check addresses properly stored
    stored_pool = await proxy_contract.get_pool_address().call()
    assert stored_pool.result == (pool_address,)
    stored_token = await proxy_contract.get_token_address().call()
    assert stored_token.result == (lp_address,)

    # NEED TO APPROVE CONTRACT TO TRANSFER FOR THIS TO WORK
    # test deposit
    await proxy_contract.mammoth_deposit(initial_deposit, user, erc20_address).invoke()
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

    # check lp tokens were minted
    user_lp_balance = await lp_token_contract.balance_of(user).call()
    assert user_lp_balance.result == (initial_deposit,)

    # increase pool contract erc20 balance (simulates profit from trading)
    await erc20_contract.mint(pool_contract.contract_address, simulated_profit).invoke()
    contract_erc20_balance = await erc20_contract.balance_of(
        pool_contract.contract_address
    ).call()

    assert contract_erc20_balance.result == (initial_deposit + simulated_profit,)

    # distribute profits
    await proxy_contract.call_distribute(erc20_address, simulated_profit).invoke()

    # check the reward sum function is correct
    S = await pool_contract.get_S().call()
    assert S.result == (
        math.floor(((simulated_profit * erc20_rounded_decimal) / initial_deposit)),
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
        (mint_amount - initial_deposit) + initial_withdrawal + simulated_profit,
    )
