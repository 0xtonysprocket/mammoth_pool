import pytest
from .conftest import DECIMALS

# from OZ utils.py


def to_uint(a):
    """Takes in value, returns uint256-ish tuple."""
    a = int(a)
    return (a & ((1 << 128) - 1), a >> 128)


def from_uint(uint):
    """Takes in uint256-ish tuple, returns value."""
    return uint[0] + (uint[1] << 128)


@pytest.mark.asyncio
async def test_get_spot_price(balancer_factory):
    balancer_contract, _ = balancer_factory

    a_balance = to_uint(10 * DECIMALS)
    a_weight = to_uint(.5 * DECIMALS)  # 1/2
    b_balance = to_uint(4 * DECIMALS)
    b_weight = to_uint(.3333333333 * DECIMALS)  # 1/3
    fee = to_uint(.01 * DECIMALS)  # 1%

    spot_price = await balancer_contract.get_spot_price(
        a_balance, a_weight, b_balance, b_weight, fee
    ).call()
    assert from_uint(spot_price.result[0]) - (1.6835016833333336 * DECIMALS) < (
        (5 * DECIMALS) / 10**6
    )


@ pytest.mark.asyncio
async def test_get_pool_minted_given_single_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    amount_of_a_in = to_uint(100 * DECIMALS)
    a_balance = to_uint(45789 * DECIMALS)
    supply = to_uint(100000 * DECIMALS)
    a_weight = to_uint(.3333333333 * DECIMALS)  # 1/3
    total_weight = to_uint(1 * DECIMALS)  # 1/1
    swap_fee = to_uint(.01 * DECIMALS)  # 1/100

    pool_minted = await balancer_contract.get_pool_minted_given_single_in(
        amount_of_a_in, a_balance, supply, a_weight, total_weight, swap_fee
    ).call()
    assert (
        from_uint(pool_minted.result[0])
        - (1354.11112 * DECIMALS)
    ) < (5 * DECIMALS) / (10 ** 6)


@ pytest.mark.asyncio
async def test_get_single_out_given_pool_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    pool_amount_in = to_uint(1000 * DECIMALS)
    a_balance = to_uint(5324 * DECIMALS)
    supply = to_uint(1234567 * DECIMALS)
    a_weight = to_uint(.3333333333 * DECIMALS)
    total_weight = to_uint(1 * DECIMALS)
    swap_fee = to_uint(.01 * DECIMALS)
    exit_fee = to_uint(.01 * DECIMALS)

    pool_minted = await balancer_contract.get_single_out_given_pool_in(
        pool_amount_in, a_balance, supply, a_weight, total_weight, swap_fee, exit_fee
    ).call()
    assert from_uint(
        pool_minted.result[0]) - (12.712380 * DECIMALS) < (5 * DECIMALS) / (10 ** 6)


@ pytest.mark.asyncio
async def test_get_out_given_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    amount_of_a_in = to_uint(100 * DECIMALS)
    a_balance = to_uint(2324 * DECIMALS)
    a_weight = to_uint(.3333333333 * DECIMALS)
    b_balance = to_uint(1234 * DECIMALS)
    b_weight = to_uint(.3333333333 * DECIMALS)
    swap_fee = to_uint(.01 * DECIMALS)

    pool_minted = await balancer_contract.get_out_given_in(
        amount_of_a_in, a_balance, a_weight, b_balance, b_weight, swap_fee
    ).call()
    assert from_uint(pool_minted.result[0]) - \
        (50.4193149 * DECIMALS) < (5 * DECIMALS) / (10 ** 7)


@ pytest.mark.asyncio
async def test_get_proportional_deposits_given_pool_out(balancer_factory):
    balancer_contract, _ = balancer_factory

    total_pool_supply = to_uint(578347 * DECIMALS)
    pool_out = to_uint(10000 * DECIMALS)
    token_list_input = [
        (1,  # token 1
         to_uint(200 * DECIMALS)),  # Uint balance of token 1
        (2,  # token 2
         to_uint(1111 * DECIMALS)),  # balance
        (3,  # token 3
         to_uint(7777 * DECIMALS)),  # balance
    ]

    list_of_deposits = await balancer_contract.get_proportional_deposits_given_pool_out(total_pool_supply, pool_out, token_list_input).call()
    assert list_of_deposits.result[0][0][0] == 1
    assert from_uint(list_of_deposits.result[0][0][1]) - (
        ((10000 * DECIMALS) / (578347 * DECIMALS)) * (200 * DECIMALS)) < 5 / (10**5)

    assert list_of_deposits.result[0][1][0] == 2
    assert from_uint(list_of_deposits.result[0][1][1]) - (
        ((10000 * DECIMALS) / (578347 * DECIMALS))
        * (1111 * DECIMALS)) < 5 / (10**5)

    assert list_of_deposits.result[0][2][0] == 3
    assert from_uint(list_of_deposits.result[0][2][1]) - (((10000 * DECIMALS) / (578347 * DECIMALS))
                                                          * (7777 * DECIMALS)) < 5 / (10**5)


@ pytest.mark.asyncio
async def test_get_proportional_withdraw_given_pool_in(balancer_factory):
    balancer_contract, _ = balancer_factory

    pool_total_supply = to_uint(578347 * DECIMALS)
    amount_in = to_uint(10000 * DECIMALS)
    exit_fee = to_uint(.001 * DECIMALS)
    token_list_input = [
        (1,  # token 1
         to_uint(200 * DECIMALS)),  # Uint balance of token 1
        (2,  # token 2
         to_uint(1111 * DECIMALS)),  # balance
        (3,  # token 3
         to_uint(7777 * DECIMALS)),  # balance
    ]

    list_of_deposits = await balancer_contract.get_proportional_withdraw_given_pool_in(pool_total_supply, amount_in, exit_fee, token_list_input).call()
    assert list_of_deposits.result[0][0][0] == 1
    assert from_uint(list_of_deposits.result[0][0][1]) - \
        ((((10000 * DECIMALS) - (10000 * DECIMALS / 1000)) /
         (578347 * DECIMALS)) * (200 * DECIMALS)) < 5 / (10**5)

    assert list_of_deposits.result[0][1][0] == 2
    assert from_uint(list_of_deposits.result[0][1][1]) - \
        ((((10000 * DECIMALS) - (10000 * DECIMALS / 1000)) /
          (578347 * DECIMALS)) * (578347 * DECIMALS)) * (1111 * DECIMALS) < 5 / (10**5)

    assert list_of_deposits.result[0][2][0] == 3
    assert from_uint(list_of_deposits.result[0][2][1]) - \
        ((((10000 * DECIMALS) - (10000 * DECIMALS / 1000)) /
          (578347 * DECIMALS)) * (7777 * DECIMALS)) < 5 / (10**5)
