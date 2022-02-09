import subprocess
import os
import dotenv
import json

dotenv.load_dotenv()

CONTRACTS_TO_COMPILE = ["mammoth_token", "mammoth_pool", "mammoth_proxy"]
ACCOUNT = json.load(open("current_account.json"))["address"]


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
    output = str(output.stdout).replace(":", "\n").split("\n")

    address = output[2].strip(" ").strip("\n")
    tx_hash = output[4].strip(" ").strip("\n")
    return address, tx_hash


def deploy(name, input_list):
    cmd = create_command(name, input_list)
    a, t = run_deploy_command(cmd)
    return a, t


dict_of_contract_info = {key: None for key in CONTRACTS_TO_COMPILE}

# deploy proxy
proxy_address, proxy_tx = deploy("mammoth_proxy", [ACCOUNT])

# deploy pool
pool_address, pool_tx = deploy("mammoth_pool", [proxy_address])

# deploy LP token
lp_name = hex(int("MAMMOTH_LP".encode().hex(), 16))
lp_symbol = hex(int("MLP".encode().hex(), 16))
token_input_list = [lp_name, lp_symbol, proxy_address]

lp_token_address, lp_token_tx = deploy("mammoth_token", token_input_list)

# store information
dict_of_contract_info = {
    "PROXY": {"address": proxy_address, "tx": proxy_tx},
    "POOL": {"address": pool_address, "tx": pool_tx},
    "LP": {"address": lp_token_address, "tx": lp_token_tx},
}

with open("current_state_info/current_deployment_info.json", "w") as file:
    file.write(str(dict_of_contract_info))
