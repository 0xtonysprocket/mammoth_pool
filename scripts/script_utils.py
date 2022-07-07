DECIMALS = 10 ** 18
MAX_FEE = 250000


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
