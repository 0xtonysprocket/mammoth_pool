import subprocess
import os
import dotenv
import json
from lib.openzeppelin.tests.utils.Signer import str_to_felt

dotenv.load_dotenv()

POOL = json.load(open("current_deployment_info.json"))["POOL"]["address"]

print(POOL)

ERC1 = [
    str(str_to_felt("testUSDC")),
    str(str_to_felt("TUSDC")),
    str(100000),
    str(0),
    str(POOL),
]

ERC2 = [
    str(str_to_felt("FantieCoin")),
    str(str_to_felt("FC")),
    str(100000),
    str(0),
    str(POOL),
]

ERC3 = [
    str(str_to_felt("testETH")),
    str(str_to_felt("TEETH")),
    str(100000),
    str(0),
    str(POOL),
]

LIST_OF_ERC = [ERC1, ERC2, ERC3]

compile_cmd_list = [
    f"starknet-compile",
    f"lib/local_cairo/fakeERC20_mintable.cairo",
    f"--output",
    f"builds/fakeERC20_mintable_compiled.json",
    f"--abi",
    f"interfaces/fakeERC20_mintable_abi.json",
]


def create_command(name_of_contract, input_list):
    cmd_list = [
        f"starknet",
        f"deploy",
        f"--contract",
        f"builds/{name_of_contract}_compiled.json",
        f'--network={os.getenv("STARKNET_NETWORK")}',
        f"--inputs",
    ]

    for i in input_list:
        cmd_list.append(i)

    return " ".join(cmd_list)


def run_deploy_command(cmd):
    output = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    print(output)
    print(output.stdout)
    output = str(output.stdout).replace(":", "\n").split("\n")

    address = output[2].strip(" ").strip("\n")
    tx_hash = output[4].strip(" ").strip("\n")
    return address, tx_hash


def deploy(name, input_list):
    cmd = create_command(name, input_list)
    a, t = run_deploy_command(cmd)
    return a, t


name_of_contracts = "fakeERC20_mintable"
list_of_fake_ercs = list()

subprocess.run(compile_cmd_list)

for inputs in LIST_OF_ERC:
    print(inputs)
    a, tx = deploy(name_of_contracts, inputs)
    fake_erc = {
        "name": inputs[0],
        "symbol": inputs[1],
        "initial": inputs[2],
        "recipient": inputs[3],
        "address": a,
        "tx": tx,
    }

    list_of_fake_ercs.append(fake_erc)

with open("fake_ercs.json", "w") as file:
    file.write(str(list_of_fake_ercs))
