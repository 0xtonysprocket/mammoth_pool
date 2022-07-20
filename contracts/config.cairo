%lang starknet

from starkware.cairo.common.uint256 import Uint256

const DECIMALS = 1000000000000000000  # 10 x 10^18
const HALF_DECIMALS = 1000000000  # MUST EQUAL 10 x 10^y where y is half of exponent in DECIMALS
const PRECISION = 1000000000  # 10 x 10^9
const MAX_DECIMAL_POW_BASE = 2 * DECIMALS - 1
const MIN_DECIMAL_POW_BASE = 1
let ONE : Uint256 = Uint256(DECIMALS, 0)
