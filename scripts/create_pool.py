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

from starknet_py.utils.crypto.facade import sign_calldata, hash_message
from starknet_py.contract import Contract
from starknet_py.net.client import Client, BadRequest
from starkware.cairo.common.hash_state import compute_hash_on_elements
from starkware.crypto.signature.signature import (
    pedersen_hash,
    private_to_stark_key,
    sign,
)

dotenv.load_dotenv()

owner_address = json.load(open(owner_account()))["address"]
router_address = json.load(open(router()))["ROUTER"]["address"]
pool_address = json.load(open(pool()))["POOL"]["address"]
ercs = [x["address"] for x in json.load(open(ercs()))]


async def create_pool(owner_address, router_address, pool_address, ercs):
    key = signer().private_key

    erc_array = list()
    for erc in ercs:
        erc_array.extend([int(erc, 16), 1, 0, 3, 0])
    erc_array_len = 3

    account_contract = await Contract.from_address(owner_address, Client("testnet"))
    proxy_contract = await Contract.from_address(router_address, Client("testnet"))

    swap_fee = (1, 0, 1000, 0)
    exit_fee = (1, 0, 1000, 0)

    (nonce,) = await account_contract.functions["get_nonce"].call()
    selector = proxy_contract.functions["create_pool"].get_selector("create_pool")
    calldata = [int(pool_address, 16), *swap_fee, *exit_fee, erc_array_len, *erc_array]
    calldata_len = len(calldata)

    message = [
        account_contract.address,
        proxy_contract.address,
        selector,
        compute_hash_on_elements(calldata),
        nonce,
    ]
    message_hash = compute_hash_on_elements(message)
    public_key = private_to_stark_key(key)
    signature = sign(msg_hash=message_hash, priv_key=key)

    input_list = [proxy_contract.address, selector, calldata_len] + calldata + [nonce]

    cmd = create_invoke_command(
        owner_address, "Account", "execute", input_list, signature
    )
    a, t = run_command(cmd)


asyncio.run(create_pool(owner_address, router_address, pool_address, ercs))

pool_info = {"address": pool_address, "ERCS": ercs, "WEIGHTS": [1 / 3, 1 / 3, 1 / 3]}
write_result_to_storage(pool_info, "current_pools")
