import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from starkware.starknet.public.abi import get_selector_from_name
from scripts.script_utils import DECIMALS, MAX_FEE
from tests.oz_utils import str_to_felt


def run(nre):
    # get user account
    user_account = nre.get_or_deploy_account("BALLER")

    # get ERC contracts
    tZWBTC, _ = tZWBTC, _ = nre.get_deployment("tZWBTC")
    tUSDC, _ = nre.get_deployment("tUSDC")
    tETH, _ = nre.get_deployment("tETH")

    # get router and pool adddress
    router_address, _ = nre.get_deployment("mammoth_router")
    pool_address, _ = nre.get_deployment("mammoth_pool")

    # setup pool
    pool_args = [
        str(str_to_felt("MAMMOTH_LP")),
        str(str_to_felt("MLP")),
        str(18),
    ]

    swap_fee = [1, 0, 1000, 0]  # 1/1000
    exit_fee = [1, 0, 1000, 0]  # 1/1000

    erc_list_len = [3]  # 3 structs of size 7 elements
    erc_list = [int(tZWBTC, 16), 1, 0, 3, 0, 5 * DECIMALS, 0, int(tUSDC, 16), 1, 0, 3,
                0, 100000 * DECIMALS, 0, int(tETH, 16), 1, 0, 3, 0, 20 * DECIMALS, 0]

    caller_address = [int(user_account.address, 16)]
    pool_address = [int(pool_address, 16)]

    create_pool_args = pool_address + pool_args + caller_address + \
        swap_fee + exit_fee + erc_list_len + erc_list

    tx = user_account.send(to="mammoth_router", method='create_pool',
                           calldata=create_pool_args, max_fee=MAX_FEE)

    print(tx)
