import sys

sys.path.append("./")
sys.path.append("../")

import subprocess
import os
import dotenv
import json
import asyncio
from contracts.lib.openzeppelin.tests.utils import Signer


dotenv.load_dotenv()

DECIMALS = 10 ** 18


def owner_account():
    return os.path.join(
        os.path.dirname(__file__),
        "../current_state_info/current_account.json",
    )


def pool():
    return os.path.join(
        os.path.dirname(__file__),
        "../current_state_info/current_deployment_info.json",
    )


def router():
    return os.path.join(
        os.path.dirname(__file__),
        "../current_state_info/current_deployment_info.json",
    )


def ercs():
    return os.path.join(
        os.path.dirname(__file__),
        "../current_state_info/fake_ercs.json",
    )


def signer():
    return Signer(int(os.getenv("PRIV_KEY"), 16))


def create_invoke_command(
    address, name_of_contract, function_name, input_list, signature
):
    cmd_list = [
        f"starknet",
        f"invoke",
        f"--address",
        f"{address}",
        f"--abi",
        f"interfaces/{name_of_contract}_abi.json",
        f"--function",
        f"{function_name}",
        f'--network={os.getenv("STARKNET_NETWORK")}',
        f'--max_fee={os.getenv("MAX_FEE")} '
        f"--inputs",
    ]

    for i in input_list:
        cmd_list.append(str(i))

    cmd_list.extend([f"--signature", f"{signature[0]}", f"{signature[1]}"])

    return " ".join(cmd_list)


def create_deploy_command(name_of_contract, input_list):
    cmd_list = [
        f"starknet",
        f"deploy",
        f"--contract",
        f"builds/{name_of_contract}_compiled.json",
        f'--network={os.getenv("STARKNET_NETWORK")}',
        f"--inputs",
    ]

    for i in input_list:
        cmd_list.append(str(i))

    return " ".join(cmd_list)


def create_compile_command(name_of_contract, name_of_compiled):
    cmd_list = [
        f"starknet-compile",
        f"contracts/{name_of_contract}.cairo",
        f"--output",
        f"builds/{name_of_compiled}_compiled.json",
        f"--abi",
        f"interfaces/{name_of_compiled}_abi.json",
    ]
    return " ".join(cmd_list)

def create_account_compile_command(name_of_contract, name_of_compiled):
    cmd_list = [
        f"starknet-compile",
        f"contracts/{name_of_contract}.cairo",
        f"--output",
        f"builds/{name_of_compiled}_compiled.json",
        f"--abi",
        f"interfaces/{name_of_compiled}_abi.json",
        f"--account_contract"
    ]
    return " ".join(cmd_list)


def run_command(cmd):
    output = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    print(output)
    print(output.stderr)
    if output.stdout:
        output = str(output.stdout).replace(":", "\n").split("\n")

        address = output[2].strip(" ").strip("\n")
        tx_hash = output[4].strip(" ").strip("\n")
        return address, tx_hash
    else:
        return None


def write_result_to_storage(result, file_name):
    with open(f"current_state_info/{file_name}.json", "w") as file:
        file.write(str(result))


def get_transaction(tx):
    cmd_list = [
        f"starknet get_transaction",
        f"--hash",
        f"{tx}",
    ]
    return " ".join(cmd_list)
