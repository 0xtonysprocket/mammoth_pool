import subprocess
import os
import dotenv
import json
import asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.public.abi import get_selector_from_name
from starkware.cairo.common.hash_state import compute_hash_on_elements
from starknet_py.utils.crypto.facade import sign_calldata, hash_message
from starknet_py.contract import Contract
from starknet_py.net.client import Client, BadRequest
from lib.openzeppelin.tests.utils.Signer import Signer, hash_message

dotenv.load_dotenv()

ACCOUNT = int(json.load(open("current_state_info/current_account.json"))["address"], 16)

PROXY = int(
    json.load(open("current_state_info/current_deployment_info.json"))["PROXY"][
        "address"
    ],
    16,
)

POOL = int(
    json.load(open("current_state_info/current_deployment_info.json"))["POOL"][
        "address"
    ],
    16,
)

LP = int(
    json.load(open("current_state_info/current_deployment_info.json"))["LP"]["address"],
    16,
)

ERCS = [
    int(x["address"], 16) for x in json.load(open("current_state_info/fake_ercs.json"))
]


SIGNER = Signer(int(os.getenv("PRIV_KEY")))


async def create_pool():
    account_contract = await Contract.from_address(ACCOUNT, Client("testnet"))
    proxy_contract = await Contract.from_address(PROXY, Client("testnet"))

    swap_fee = (1, 1000)
    exit_fee = (1, 1000)

    print("creating pool")

    # Create Pool
    (nonce,) = await account_contract.functions["get_nonce"].call()
    selector = proxy_contract.functions["create_pool"].get_selector("create_pool")
    calldata = [LP, POOL, swap_fee[0], swap_fee[1], exit_fee[0], exit_fee[1]]

    message_hash = hash_message(ACCOUNT, PROXY, selector, calldata, nonce)
    sig_r, sig_s = SIGNER.sign(message_hash)
    sig = [sig_r, sig_s]

    prepared = await account_contract.functions["execute"].invoke(
        to=PROXY, selector=selector, calldata=calldata, nonce=nonce, signature=sig
    )

    """
    calldata_hash = compute_hash_on_elements(calldata)
    list_of_args = [ACCOUNT, PROXY, selector] + calldata + [nonce]

    # msg_hash = hash_message(ACCOUNT, PROXY, selector, call)

    print(SIGNER.private_key)
    print(list_of_args)

    sig = sign_calldata(calldata=list_of_args, priv_key=SIGNER.private_key)
    # message_hash = hash_message(ACCOUNT, PROXY, selector, calldata, nonce)
    # sig_r, sig_s = SIGNER.sign(message_hash)
    # sig = [sig_r, sig_s]
    invocation = await prepared.invoke(sig)

    print(invocation)

    output = await invocation.wait_for_acceptance()
    """

    print(prepared)

    (stored,) = await proxy_contract.functions["is_pool_approved"].call(POOL)
    print(stored)
    assert stored == 1

    # add ERC20s

    weight = (1, 3)

    for erc in ERCS:
        print(ERCS)
        (nonce,) = await account_contract.functions["get_nonce"].call()
        selector = get_selector_from_name("create_pool")
        calldata = [POOL, erc, weight[0], weight[1]]
        prepared = account_contract.functions["execute"].prepare(
            to=PROXY, selector=selector, calldata_len=4, calldata=calldata, nonce=nonce
        )

        calldata_hash = compute_hash_on_elements(calldata)
        list_of_args = [ACCOUNT, PROXY, selector, 6, calldata_hash, nonce]

        signature = sign_calldata(
            calldata,
            int(SIGNER.private_key),
        )
        # message_hash = hash_message(ACCOUNT, PROXY, selector, calldata, nonce)
        # sig_r, sig_s = SIGNER.sign(message_hash)
        # sig = [sig_r, sig_s]

        invocation = await prepared.invoke(signature=signature)
        output = await invocation.wait_for_acceptance()

        print(output)

        (stored,) = await account_contract.functions["is_erc20_approved"].call(
            POOL, erc
        )
        assert stored == 1


asyncio.run(create_pool())


pool_info = {"address": POOL, "ERCS": ERCS, "WEIGHTS": [1 / 3, 1 / 3, 1 / 3]}

with open("current_state_info/current_pools.json", "w") as file:
    file.write(str(pool_info))
