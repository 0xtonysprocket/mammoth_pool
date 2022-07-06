from script_utils import (
    create_account_compile_command,
    create_deploy_command,
    write_result_to_storage,
    run_command,
    signer,
)

account_path = "lib/openzeppelin/contracts/Account"
account = "Account"
signer = signer()

c_cmd = create_account_compile_command(account_path, account)
x = run_command(c_cmd)


d_cmd = create_deploy_command(account, [signer.public_key])
a, t = run_command(d_cmd)

result = {"address": a, "tx": t}
write_result_to_storage(result, "current_account")
