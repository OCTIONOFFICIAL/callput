pragma solidity 0.8.3;

import "../Interfaces/Interfaces.sol";
import "../utils/Math.sol";

contract PriceCalculator is IPriceCalculator, Ownable {
    using SafeMath for uint256;
    using OctiMath for uint256;

    uint256[3] public impliedVolRate;
    uint256 internal constant PRICE_DECIMALS = 1e8;
    uint256 internal constant PRICE_MODIFIER_DECIMALS = 1e8;
    uint256 internal immutable DECIMALS_DIFF;
    uint256 public utilizationRate = 1e8;
    AggregatorV3Interface public priceProvider;
    IOctiLiquidityPool assetPool;
    IOctiLiquidityPool stablePool;

    constructor(
        uint256[3] memory initialRates,
        AggregatorV3Interface _priceProvider,
        IOctiLiquidityPool _assetPool,
        IOctiLiquidityPool _stablePool,
        uint8 tokenDecimalsDiff
    ) {
        assetPool = _assetPool;
        stablePool = _stablePool;
        priceProvider = _priceProvider;
        impliedVolRate = initialRates;
        DECIMALS_DIFF = 10**tokenDecimalsDiff;
    }

    /**
     * @notice Used for adjusting the options prices while balancing asset's implied volatility rate
     * @param values New IVRate values
     */
    function setImpliedVolRate(uint256[3] calldata values) external onlyOwner {
        impliedVolRate = values;
    }

    /**
     * @notice Used for getting the actual options prices
     * @param period Option period in seconds (1 days <= period <= 12 weeks)
     * @param amount Option amount
     * @param strike Strike price of the option
     * @return settlementFee Amount to be distributed to the Octi token holders
     * @return premium Option fee amount
     */
    function fees(
        uint256 period,
        uint256 amount,
        uint256 strike,
        IOctiOptions.OptionType optionType
    ) public view override returns (uint256 settlementFee, uint256 premium) {
        uint256 currentPrice = _currentPrice();
        require(
            strike == currentPrice || strike == 0,
            "Only ATM options are currently available"
        );
        return (
            getSettlementFee(amount, optionType, currentPrice),
            getPeriodFee(amount, period, currentPrice, optionType)
        );
    }

    /**
     * @notice Calculates settlementFee
     * @param amount Option amount
     * @return fee Settlement fee amount
     */
    function getSettlementFee(
        uint256 amount,
        IOctiOptions.OptionType optionType,
        uint256 currentPrice
    ) internal pure returns (uint256 fee) {
        if (optionType == IOctiOptions.OptionType.Call) return amount / 100;
        if (optionType == IOctiOptions.OptionType.Put)
            return (amount * currentPrice) / PRICE_DECIMALS / 100;
    }

    /**
     * @notice Calculates periodFee
     * @param amount Option amount
     * @param period Option period in seconds (1 days <= period <= 12 weeks)
     * @return fee Period fee amount
     */

    function getPeriodFee(
        uint256 amount,
        uint256 period,
        uint256 currentPrice,
        IOctiOptions.OptionType optionType
    ) internal view returns (uint256 fee) {
        if (optionType == IOctiOptions.OptionType.Put)
            return
                (amount *
                    currentPrice *
                    _priceModifier(amount, period, stablePool)) /
                PRICE_MODIFIER_DECIMALS /
                PRICE_DECIMALS /
                DECIMALS_DIFF;
        if (optionType == IOctiOptions.OptionType.Call)
            return
                (amount * _priceModifier(amount, period, assetPool)) /
                PRICE_DECIMALS;
    }

    function _priceModifier(
        uint256 amount,
        uint256 period,
        IOctiLiquidityPool pool
    ) internal view returns (uint256 iv) {
        uint256 poolBalance = pool.totalBalance();
        require(poolBalance > 0, "Pool is empty");

        if (period < 1 weeks) iv = impliedVolRate[0];
        else if (period < 4 weeks) iv = impliedVolRate[1];
        else iv = impliedVolRate[2];

        iv *= period.sqrt();

        uint256 lockedAmount = pool.lockedAmount() + amount;
        uint256 utilization = (lockedAmount * 100e8) / poolBalance;

        if (utilization > 40e8) {
            iv += (iv * (utilization - 40e8) * utilizationRate) / 40e16;
        }
    }

    function _currentPrice() internal view returns (uint256 price) {
        (, int256 latestPrice, , , ) = priceProvider.latestRoundData();
        price = uint256(latestPrice);
    }
}
