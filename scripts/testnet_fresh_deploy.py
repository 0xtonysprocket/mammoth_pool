import os
import sys
import time

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from tests.oz_utils import str_to_felt, to_uint, felt_to_str
from scripts.script_utils import (
    DECIMALS, MAX_FEE
)


def run(nre):
    # get account to work with
    owner_account = nre.get_or_deploy_account("BALLER")

    # declare pool proxy
    try:
        proxy_class = nre.declare(
            contract="Proxy", alias="Proxy_Class")
        print("Proxy Class Declared")
    except Exception as e:
        print(e)
        proxy_class = nre.get_declaration("Proxy_Class")

    # declare pool
    try:
        pool_class = nre.declare(contract="mammoth_pool", alias="Pool_Class")
        print("Pool Class declared")
    except Exception as e:
        print(e)
        pool_class = nre.get_declaration("Pool_Class")

    # declare router
    try:
        router_class = nre.declare(
            contract="mammoth_router", alias="Router_Class")
        print("Router Class declared")
    except Exception as e:
        print(e)
        router_class = nre.get_declaration("Router_Class")

    # deploy router
    try:
        router_address, router_abi = nre.deploy(
            contract="Proxy", arguments=[router_class, owner_account.address], alias="mammoth_router")

        print("ROUTER DEPLOYED")
    except Exception as e:
        print(e)
        router_address, _ = nre.get_deployment("mammoth_router")

    # wait for transaction to get accepted
     time.sleep(180)

    # initialize router
    try:
         initialize_router = owner_account.send(to="mammoth_router", method="initialize", calldata=[
                                               int(owner_account.address, 16)], max_fee = MAX_FEE)
        print("Router Initialized")
    except Exception as e:
        print(e)

    # wait for transaction to get accepted
     time.sleep(180)

    # set proxy and pool class hash
     success = owner_account.send(to="mammoth_router", method="set_proxy_class_hash", calldata=[
        int(proxy_class, 16)], max_fee=MAX_FEE)

     assert success == 1
     print(success)
     print("Proxy Hash Set Successfully")

    success = owner_account.send(to="mammoth_router", method="define_pool_type_class_hash", calldata=[
        str(str_to_felt("DEFAULTv0")), int(pool_class, 16)], max_fee=MAX_FEE)

    # wait for transaction to get accepted
     time.sleep(180)

    # assert success == 1
    print(success)
    print("Pool Hash Set Successfully")

    # wait for transactions to get accepted
    time.sleep(180)

    # deploy pool
    pool_address = owner_account.send(to="mammoth_router", method="deploy_pool",
                                      calldata=[str(str_to_felt("DEFAULTv0")), int(owner_account.address, 16)], max_fee=MAX_FEE)

    print(pool_address)

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
        try:
            erc_address, erc_abi = nre.deploy(
                contract="Non_owner_ERC20_mintable", arguments=erc[0], alias=erc[1])
            print(f'{erc[1]} DEPLOYED')
        except Exception as e:
            print(e)
