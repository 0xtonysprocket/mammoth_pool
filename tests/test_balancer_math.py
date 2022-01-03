import pytest
import math


@pytest.mark.asyncio
async def test_get_spot_price(balancer_factory):
    balancer_contract, _ = balancer_factory

    a_balance = 10
    a_weight = (1, 2)  # 1/2
    b_balance = 4
    b_weight = (1, 3)  # 1/3
    fee = (1, 100)  # 1%

    spot_price = await balancer_contract.get_spot_price(
        a_balance, a_weight, b_balance, b_weight, fee
    ).call()
    assert spot_price.result[0] == (3000, 792)


@pytest.mark.asyncio
async def test_get_pool_minted_given_single_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    amount_of_a_in = 21376
    a_balance = 45789
    supply = 10000
    a_weight = (1, 3)  # 1/3
    total_weight = (1, 1)  # 1/1
    swap_fee = (1, 100)  # 1/100

    pool_minted = await balancer_contract.get_pool_minted_given_single_in(
        amount_of_a_in, a_balance, supply, a_weight, total_weight, swap_fee
    ).call()
    assert (pool_minted.result[0][0] / pool_minted.result[0][1] - 1354.11112) < 5 / (
        10 ** 6
    )


@pytest.mark.asyncio
async def test_get_single_out_given_pool_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    pool_amount_in = 1000
    a_balance = 5324
    supply = 1234567
    a_weight = (1, 3)
    total_weight = (1, 1)
    swap_fee = (1, 100)
    exit_fee = (1, 100)

    pool_minted = await balancer_contract.get_single_out_given_pool_in(
        pool_amount_in, a_balance, supply, a_weight, total_weight, swap_fee, exit_fee
    ).call()
    assert pool_minted.result[0][0] / pool_minted.result[0][1] - 12.712370 < 5 / (
        10 ** 6
    )


@pytest.mark.asyncio
async def test_get_out_given_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    amount_of_a_in = 100
    a_balance = 2324
    a_weight = (1, 3)
    b_balance = 1234
    b_weight = (1, 3)
    swap_fee = (1, 100)

    pool_minted = await balancer_contract.get_out_given_in(
        amount_of_a_in, a_balance, a_weight, b_balance, b_weight, swap_fee
    ).call()
    assert pool_minted.result[0][0] / pool_minted.result[0][1] - 50.4193149 < 5 / (
        10 ** 7
    )
