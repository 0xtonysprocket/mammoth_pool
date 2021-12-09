import os
import asyncio
import pytest

from ..lib.openzeppelin.tests.utils.Signer import Signer

from starkware.starknet.testing.starknet import Starknet

# contract and library paths
POOL_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/mammoth_pool.cairo"
)

PROXY_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/mammoth_proxy.cairo"
)

LP_TOKEN_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/mammoth_token.cairo"
)

ERC20_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../lib/openzeppelin/contracts/token/ERC20.cairo"
)

ACCOUNT_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../lib/openzeppelin/contracts/Account.cairo"
)

ERC20_DIGIT = 1000000000


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


# contract and object factories
@pytest.fixture(scope="module")
async def starknet_factory():
    starknet = await Starknet.empty()
    return starknet


@pytest.fixture(scope="module")
async def signer_factory():
    signer = Signer(12345)
    return signer


@pytest.fixture(scope="module")
async def account_factory(starknet_factory, signer_factory):
    starknet = starknet_factory
    signer = signer_factory

    # Deploy the account contract
    user_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT, constructor_calldata=[signer.public_key]
    )

    return user_account, user_account.contract_address


@pytest.fixture(scope="module")
async def proxy_factory(starknet_factory, account_factory):
    starknet = starknet_factory
    _, user = account_factory

    proxy_contract = await starknet.deploy(
        source=PROXY_CONTRACT,
        constructor_calldata=[user],
    )

    return proxy_contract, proxy_contract.contract_address


@pytest.fixture(scope="module")
async def pool_factory(starknet_factory, proxy_factory):
    starknet = starknet_factory
    _, proxy_address = proxy_factory

    pool_contract = await starknet.deploy(
        source=POOL_CONTRACT,
        constructor_calldata=[proxy_address],
    )

    return pool_contract, pool_contract.contract_address


@pytest.fixture(scope="module")
async def lp_token_factory(starknet_factory, proxy_factory):
    starknet = starknet_factory
    _, proxy_address = proxy_factory

    lp_name = int("TEST_LP".encode().hex(), 16)
    lp_symbol = int("TLP".encode().hex(), 16)

    lp_token_contract = await starknet.deploy(
        source=LP_TOKEN_CONTRACT,
        # extra 0 to handle the fact that ERC needs Uint256 as input
        constructor_calldata=[lp_name, lp_symbol, proxy_address],
    )

    return lp_token_contract, lp_token_contract.contract_address


@pytest.fixture(scope="module")
async def erc20_factory(starknet_factory, account_factory):
    starknet = starknet_factory
    _, user = account_factory

    erc_name = int("TEST".encode().hex(), 16)
    erc_symbol = int("T".encode().hex(), 16)
    mint_amount = 1000 * ERC20_DIGIT

    erc20_contract = await starknet.deploy(
        source=ERC20_CONTRACT,
        # extra 0 to handle the fact that ERC needs Uint256 as input
        constructor_calldata=[erc_name, erc_symbol, mint_amount, 0, user],
    )

    return erc20_contract, erc20_contract.contract_address
