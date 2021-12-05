import os
import pytest
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

    # Deploy the contract.
    pool_contract = await starknet.deploy(
        source=POOL_CONTRACT,
    )

    erc20_contract = await starknet.deploy(
        source=ERC20_CONTRACT, constructor_calldata=[ERC_NAME, ERC_SYMBOL, user]
    )

    # define contract variables
    erc20_address = erc20_contract.contract_address

    # NEED TO APPROVE CONTRACT TO TRANSFER FOR THIS TO WORK
    # test deposit
    await pool_contract.proxy_deposit(10000, user, erc20_address).invoke()

    # new total stake
    total_staked = await pool_contract.get_total_staked().call()
    assert total_staked.result == (10000,)

    # total accrued rewards check
    S = await pool_contract.get_S().call()
    assert S.result == (0,)

    # check user balance
    user_balance = await pool_contract.get_user_balance(user, erc20_address).call()
    assert user_balance.result == (10000,)
