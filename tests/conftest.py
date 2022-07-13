import os
import asyncio
import pytest

from starkware.starknet.testing.starknet import Starknet
from .oz_signers import MockSigner
from .oz_utils import str_to_felt, to_uint

DECIMALS = 10 ** 18


# contract and library paths
PROXY_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/lib/Proxy.cairo"
)

POOL_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/mammoth_pool.cairo"
)

ROUTER_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/mammoth_router.cairo"
)

ERC20_CONTRACT = os.path.join(
    os.path.dirname(__file__),
    "../contracts/lib/Non_owner_ERC20_Mintable.cairo",
)

ACCOUNT_CONTRACT = os.path.join(
    os.path.dirname(
        __file__), "../contracts/lib/Account.cairo"
)

BALANCER_CONTRACT = os.path.join(
    os.path.dirname(__file__), "../contracts/lib/balancer_math.cairo"
)


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
    signer = MockSigner(12345)
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
async def class_hash_factory(starknet_factory, signer_factory):
    starknet = starknet_factory
    signer = signer_factory

    # Declare the proxy contract
    proxy = await starknet.declare(source=PROXY_CONTRACT)
    proxy_hash = proxy.class_hash

    pool = await starknet.declare(source=POOL_CONTRACT)
    pool_hash = pool.class_hash
    pool_abi = pool.abi

    router = await starknet.declare(source=ROUTER_CONTRACT)
    router_hash = router.class_hash

    return proxy_hash, pool_hash, router_hash, pool_abi


@pytest.fixture(scope="module")
async def router_factory(starknet_factory, signer_factory, account_factory, class_hash_factory):
    starknet = starknet_factory
    signer = signer_factory
    _, _, router_hash, _ = class_hash_factory
    user_account, user = account_factory

    # deploy router
    router_contract = await starknet.deploy(
        source=PROXY_CONTRACT,
        constructor_calldata=[router_hash, user],
    )

    # initialize router
    await signer.send_transaction(
        account=user_account,
        to=router_contract.contract_address,
        selector_name="initialize",
        calldata=[user],
    )

    return router_contract, router_contract.contract_address

# will be assigned in test deploy pool


@pytest.fixture(scope="module")
async def pool_factory():
    return {}


@pytest.fixture(scope="module")
async def tusdc_factory(starknet_factory, account_factory):
    starknet = starknet_factory
    _, user = account_factory

    tusdc = await starknet.deploy(
        ERC20_CONTRACT,
        constructor_calldata=[
            str_to_felt("testUSDC"),
            str_to_felt("TUSDC"),
            18,
            *to_uint(900000 * DECIMALS),
            user,
            user
        ],
    )

    return tusdc, tusdc.contract_address


@pytest.fixture(scope="module")
async def fc_factory(starknet_factory, account_factory):
    starknet = starknet_factory
    _, user = account_factory

    fc = await starknet.deploy(
        ERC20_CONTRACT,
        constructor_calldata=[
            str_to_felt("FantieCoin"),
            str_to_felt("FC"),
            18,
            *to_uint(900000 * DECIMALS),
            user,
            user
        ],
    )

    return fc, fc.contract_address


@pytest.fixture(scope="module")
async def teeth_factory(starknet_factory, account_factory):
    starknet = starknet_factory
    _, user = account_factory

    teeth = await starknet.deploy(
        ERC20_CONTRACT,
        constructor_calldata=[
            str_to_felt("testETH"),
            str_to_felt("TEETH"),
            18,
            *to_uint(900000 * DECIMALS),
            user,
            user,
        ],
    )

    return teeth, teeth.contract_address


@pytest.fixture(scope="module")
async def balancer_factory(starknet_factory):
    starknet = starknet_factory

    balancer_contract = await starknet.deploy(source=BALANCER_CONTRACT)

    return balancer_contract, balancer_contract.contract_address
