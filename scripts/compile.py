from script_utils import create_compile_command, run_command

CONTRACTS_TO_COMPILE = [
    [
        "mammoth_router",
        "mammoth_router",
    ],
    ["mammoth_pool", "mammoth_pool"],
    ["lib/Non_owner_ERC20_Mintable", "fake_erc"],
]

for contract in CONTRACTS_TO_COMPILE:
    cmd = create_compile_command(contract[0], contract[1])
    w = run_command(cmd)
