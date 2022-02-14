import sys

sys.path.append("./")
sys.path.append("../")

import json
from script_utils import (
    create_deploy_command,
    run_command,
    write_result_to_storage,
    owner_account,
)

from contracts.lib.openzeppelin.tests.utils import str_to_felt, to_uint, felt_to_str

owner = json.load(open(owner_account()))["address"]

router_deploy = create_deploy_command("mammoth_router", [owner])
router_address, rtx = run_command(router_deploy)

pool_deploy = create_deploy_command(
    "mammoth_pool",
    [
        router_address,
        str_to_felt("MAMMOTH_LP"),
        str_to_felt("MLP"),
        *to_uint(1000),
        owner,
    ],
)

pool_address, ptx = run_command(pool_deploy)

erc_one = [
    str_to_felt("FantieCoin"),
    str_to_felt("FC"),
    *to_uint(1000),
    pool_address,
    owner,
]
erc_two = [
    str_to_felt("testUSDC"),
    str_to_felt("TUSDC"),
    *to_uint(1000),
    pool_address,
    owner,
]
erc_three = [
    str_to_felt("testETH"),
    str_to_felt("TEETH"),
    *to_uint(1000),
    pool_address,
    owner,
]
list_of_erc = [erc_one, erc_two, erc_three]

list_of_erc_data = list()
for erc in list_of_erc:
    cmd = create_deploy_command("fake_erc", erc)
    a, t = run_command(cmd)

    data = {
        "name": felt_to_str(erc[0]),
        "symbol": felt_to_str(erc[1]),
        "address": a,
        "transaction": t,
    }
    list_of_erc_data.append(data)


pool_router_dict = {
    "ROUTER": {"address": router_address, "transaction": rtx},
    "POOL": {"address": pool_address, "transaction": ptx},
}
write_result_to_storage(pool_router_dict, "current_deployment_info")
write_result_to_storage(list_of_erc_data, "fake_ercs")
