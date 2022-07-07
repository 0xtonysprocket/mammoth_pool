import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from scripts.script_utils import DECIMALS, MAX_FEE

def run(nre):
    # get user account
    user_account = nre.get_or_deploy_account("BALLER")

    # get ERC contracts
    erc_list = tZWBTC, _ = nre.get_deployment("tZWBTC")
    tUSDC, _ = nre.get_deployment("tUSDC")
    tETH, _ = nre.get_deployment("tETH")

    # get pool adddress
    pool_address, _ = nre.get_deployment("mammoth_pool")

    # approve pool to spend args
    approve_args = [int(pool_address, 16), 400000*DECIMALS]

    # send tx
    tx_one = user_account.send(to=tZWBTC, method='approve', calldata=approve_args, max_fee=MAX_FEE)
    tx_two = user_account.send(to=tUSDC, method='approve', calldata=approve_args, max_fee=MAX_FEE)
    tx_three = user_account.send(to=tETH, method='approve', calldata=approve_args, max_fee=MAX_FEE)

    print(tx_one)
    print(tx_two)
    print(tx_three)