import os
import sys

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from tests.oz_utils import str_to_felt, to_uint, felt_to_str
from scripts.script_utils import (
    DECIMALS
)


def run(nre):
    # get account to work with
    owner_account = nre.get_or_deploy_account("BALLER")

    # deploy router
    router_address, router_abi = nre.deploy(
        contract="mammoth_router", arguments=[owner_account.address], alias="mammoth_router")

    print("ROUTER DEPLOYED")

    # deploy pool
    pool_args = [
        router_address,
        str(str_to_felt("MAMMOTH_LP")),
        str(str_to_felt("MLP")),
        str(18),
    ]
    pool_address, pool_abi = nre.deploy(
        contract="mammoth_pool", arguments=pool_args, alias="mammoth_pool")

    print("POOL DEPLOYED")

    # deploy 3 ERCs
    erc_one_args = [[
        str(str_to_felt("tZWBTC")),
        str(str_to_felt("tZWBTC")),
        str(18),
        str(5000000 * DECIMALS),
        str(0),
        owner_account.address,
        owner_account.address,
    ], "tZWBTC"]
    erc_two_args = [[
        str(str_to_felt("tUSDC")),
        str(str_to_felt("tUSDC")),
        str(18),
        str(5000000 * DECIMALS),
        str(0),
        owner_account.address,
        owner_account.address,
    ], "tUSDC"]
    erc_three_args = [[
        str(str_to_felt("tETH")),
        str(str_to_felt("tETH")),
        str(18),
        str(5000000 * DECIMALS),
        str(0),
        owner_account.address,
        owner_account.address,
    ], "tETH"]
    list_of_erc = [erc_one_args, erc_two_args, erc_three_args]

    list_of_erc_data = list()
    for erc in list_of_erc:
        erc_address, erc_abi = nre.deploy(
            contract="Non_owner_ERC20_mintable", arguments=erc[0], alias=erc[1])

        print(f'{erc[1]} DEPLOYED')
