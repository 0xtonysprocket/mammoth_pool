import subprocess

CONTRACTS_TO_COMPILE = ["mammoth_token", "mammoth_pool", "mammoth_proxy"]


def create_command(name_of_contract):
    cmd_list = [
        f"starknet-compile",
        f"contracts/{name_of_contract}.cairo",
        f"--output",
        f"builds/{name_of_contract}_compiled.json",
        f"--abi",
        f"interfaces/{name_of_contract}_abi.json",
    ]
    return cmd_list


for contract in CONTRACTS_TO_COMPILE:
    cmd = create_command(contract)
    subprocess.run(cmd)
