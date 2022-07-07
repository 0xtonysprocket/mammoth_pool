import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from scripts.script_utils import DECIMALS, MAX_FEE, write_result_to_storage


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

    swap_fee = [1, 0, 1000, 0]  # 1/1000
    exit_fee = [1, 0, 1000, 0]  # 1/1000

    erc_list_len = [3]  # 3 structs of size 7 elements
    erc_list = [int(tZWBTC, 16), 1, 0, 3, 0, 5 * DECIMALS, 0, int(tUSDC, 16), 1, 0, 3,
                0, 100000 * DECIMALS, 0, int(tETH, 16), 1, 0, 3, 0, 20 * DECIMALS, 0]

    caller_and_pool_address = [int(user_account.address, 16),
                               int(pool_address, 16)]

    create_pool_args = caller_and_pool_address + \
        swap_fee + exit_fee + erc_list_len + erc_list

    tx = user_account.send(to="mammoth_router", method='create_pool',
                           calldata=create_pool_args, max_fee=MAX_FEE)

    print(tx)

    pool_info = {"address": pool_address,
                 "ERCS": [tZWBTC, tUSDC, tETH], "WEIGHTS": [1 / 3, 1 / 3, 1 / 3]}
    write_result_to_storage(pool_info, "current_pools")
