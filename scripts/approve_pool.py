import asyncio
import json
import dotenv
import os
from script_utils import (
    create_invoke_command,
    run_command,
    write_result_to_storage,
    owner_account,
    router,
    pool,
    ercs,
    signer,
)
from script_utils import DECIMALS

from starknet_py.contract import Contract
from starknet_py.net.client import Client
from starkware.cairo.common.hash_state import compute_hash_on_elements
from starkware.crypto.signature.signature import (
    private_to_stark_key,
    sign,
)

dotenv.load_dotenv()

owner_address = json.load(open(owner_account()))["address"]
router_address = json.load(open(router()))["ROUTER"]["address"]
pool_address = json.load(open(pool()))["POOL"]["address"]
ercs = [x["address"] for x in json.load(open(ercs()))]
nonce = 0


async def approve_pool(owner_address, router_address, pool_address, ercs, nonce):
    key = signer().private_key

    i_i = [pool_address, 400000*DECIMALS]

    account_contract = await Contract.from_address(owner_address, Client("testnet"))

    for erc in ercs:
        erc_contract = await Contract.from_address(erc, Client("testnet"))

        # (nonce,) = await account_contract.functions["get_nonce"].call()
        nonce = nonce + 1
        selector = erc_contract.functions["approve"].get_selector(
            "approve")
        print(selector)
        calldata = i_i
        calldata_len = len(calldata)

        message = [
            erc_contract.address,
            selector,
            0,
            2,
        ]
        message_hash = compute_hash_on_elements(message)
        public_key = private_to_stark_key(key)
        signature = sign(msg_hash=message_hash, priv_key=key)

        input_list = [message] + calldata + [nonce]

        cmd = create_invoke_command(
            owner_address, "Account", "__execute__", input_list, signature
        )
        a, t = run_command(cmd)


asyncio.run(approve_pool(owner_address,
            router_address, pool_address, ercs, nonce))
