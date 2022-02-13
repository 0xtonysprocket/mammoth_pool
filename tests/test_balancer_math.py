import pytest
import math

# from OZ utils.py
def to_uint(a):
    """Takes in value, returns uint256-ish tuple."""
    return (a & ((1 << 128) - 1), a >> 128)


def from_uint(uint):
    """Takes in uint256-ish tuple, returns value."""
    return uint[0] + (uint[1] << 128)


@pytest.mark.asyncio
async def test_get_spot_price(balancer_factory):
    balancer_contract, _ = balancer_factory

    a_balance = to_uint(10)
    a_weight = (to_uint(1), to_uint(2))  # 1/2
    b_balance = to_uint(4)
    b_weight = (to_uint(1), to_uint(3))  # 1/3
    fee = (to_uint(1), to_uint(100))  # 1%

    spot_price = await balancer_contract.get_spot_price(
        a_balance, a_weight, b_balance, b_weight, fee
    ).call()
    assert (from_uint(spot_price.result[0][0]), from_uint(spot_price.result[0][1])) == (
        3000,
        792,
    )


@pytest.mark.asyncio
async def test_get_pool_minted_given_single_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    amount_of_a_in = to_uint(21376)
    a_balance = to_uint(45789)
    supply = to_uint(10000)
    a_weight = (to_uint(1), to_uint(3))  # 1/3
    total_weight = (to_uint(1), to_uint(1))  # 1/1
    swap_fee = (to_uint(1), to_uint(100))  # 1/100

    pool_minted = await balancer_contract.get_pool_minted_given_single_in(
        amount_of_a_in, a_balance, supply, a_weight, total_weight, swap_fee
    ).call()
    assert (
        from_uint(pool_minted.result[0][0]) / from_uint(pool_minted.result[0][1])
        - 1354.11112
    ) < 5 / (10 ** 6)


@pytest.mark.asyncio
async def test_get_single_out_given_pool_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    pool_amount_in = to_uint(1000)
    a_balance = to_uint(5324)
    supply = to_uint(1234567)
    a_weight = (to_uint(1), to_uint(3))
    total_weight = (to_uint(1), to_uint(1))
    swap_fee = (to_uint(1), to_uint(100))
    exit_fee = (to_uint(1), to_uint(100))

    pool_minted = await balancer_contract.get_single_out_given_pool_in(
        pool_amount_in, a_balance, supply, a_weight, total_weight, swap_fee, exit_fee
    ).call()
    assert from_uint(pool_minted.result[0][0]) / from_uint(
        pool_minted.result[0][1]
    ) - 12.712370 < 5 / (10 ** 6)


@pytest.mark.asyncio
async def test_get_out_given_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    amount_of_a_in = to_uint(100)
    a_balance = to_uint(2324)
    a_weight = (to_uint(1), to_uint(3))
    b_balance = to_uint(1234)
    b_weight = (to_uint(1), to_uint(3))
    swap_fee = (to_uint(1), to_uint(100))

    pool_minted = await balancer_contract.get_out_given_in(
        amount_of_a_in, a_balance, a_weight, b_balance, b_weight, swap_fee
    ).call()
    assert from_uint(pool_minted.result[0][0]) / from_uint(
        pool_minted.result[0][1]
    ) - 50.4193149 < 5 / (10 ** 7)
