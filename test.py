DECIMALS = 10**18

amount_of_a_in = 100 * DECIMALS
a_balance = 45789 * DECIMALS
supply = 100000 * DECIMALS
a_weight = .3333333333  # 1/3
total_weight = 1 * DECIMALS  # 1/1
swap_fee = .01  # 1/100


weight_rat = a_weight
fee_adj = 1 - ((1 - weight_rat) * swap_fee)
adj_amount_in = amount_of_a_in * fee_adj
new_bal = a_balance + adj_amount_in
bal_rat = new_bal / a_balance
multiplier = bal_rat ** weight_rat
new_supply = supply * multiplier
amount_mint = new_supply - supply


print(amount_mint)
