import subprocess
import os
import dotenv
from lib.openzeppelin.tests.utils.Signer import Signer

dotenv.load_dotenv()

signer = Signer(int(os.getenv("PRIV_KEY")))


compile_cmd_list = [
    f"starknet-compile",
    f"lib/openzeppelin/contracts/Account.cairo",
    f"--output",
    f"builds/Account_compiled.json",
    f"--abi",
    f"interfaces/Account_abi.json",
]

deploy_cmd_list = [
    f"starknet",
    f"deploy",
    f"--contract",
    f"builds/Account_compiled.json",
    f"--inputs",
    f"{signer.public_key}",
    f'--network={os.getenv("STARKNET_NETWORK")}',
]

subprocess.run(compile_cmd_list)

output = subprocess.run(deploy_cmd_list, capture_output=True, text=True)
output = str(output.stdout).replace(":", "\n").split("\n")

address = output[2].strip(" ").strip("\n")
tx_hash = output[4].strip(" ").strip("\n")

dict_of_contract_info = {"address": address, "tx": tx_hash}

with open("current_account.json", "w") as file:
    file.write(str(dict_of_contract_info))
