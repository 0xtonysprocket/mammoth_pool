def run(nre):
    # get user account
    user_account = nre.get_or_deploy_account("BALLER")

    # get ERC contracts
    tZWBTC, _ = tZWBTC, _ = nre.get_deployment("tZWBTC")
    tUSDC, _ = nre.get_deployment("tUSDC")
    tETH, _ = nre.get_deployment("tETH")

    # get router and pool adddress
    router_address, _ = nre.get_deployment("mammoth_router")
    pool_address, _ = nre.get_deployment("mammoth_pool")

    # check if pool is approved
    is_pool_approved = nre.call(contract=router_address,
                                method="is_pool_approved", params=[pool_address])

    try:
        assert int(is_pool_approved) == 1
        print("Pool Approved Properly")
    except:
        print("ERROR POOL NOT APPROVED")

    # check ERC approval
    is_zwbtc_approved = nre.call(
        contract=pool_address, method="is_ERC20_approved", params=[tZWBTC])
    is_tusdc_approved = nre.call(
        contract=pool_address, method="is_ERC20_approved", params=[tUSDC])
    is_tETH_approved = nre.call(
        contract=pool_address, method="is_ERC20_approved", params=[tETH])

    try:
        assert int(is_zwbtc_approved) == 1
        print("tZWBTC approved properly")

        assert int(is_tusdc_approved) == 1
        print("tUSDC approved properly")

        assert int(is_tETH_approved) == 1
        print("tETH approved properly")
    except:
        print("ERROR ONE OR MORE ERC NOT APPROVED")

    # check balances
    # initial balances should be:
    # tZWBTC 5 * 10**18
    # tUSDC 100000 * 10**18
    # tETH 20 * 10**18

    pool_tzwbtc_balance = nre.call(
        contract=tZWBTC, method="balanceOf", params=[pool_address])
    pool_tusdc_balance = nre.call(
        contract=tUSDC, method="balanceOf", params=[pool_address])
    pool_teth_balance = nre.call(
        contract=tETH, method="balanceOf", params=[pool_address])

    try:
        assert int(pool_tzwbtc_balance.split(" ")[0], 16) == 5 * 10**18
        print("tZWBTC balance is correct")

        assert int(pool_tusdc_balance.split(" ")[0], 16) == 100000 * 10**18
        print("tUSDC balance is correct")

        assert int(pool_teth_balance.split(" ")[0], 16) == 20 * 10**18
        print("tETH balance is correct")

    except:
        print(
            "ERROR CASE 1: ONE OR MORE BALANCE NOT CORRECT AFTER INITIALIZATION [FIX] \n CASE 2: POOL HAS BEEN USED [IGNORE]")
