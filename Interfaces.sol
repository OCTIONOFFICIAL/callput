pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";

interface IOctiLiquidityPool is IERC721 {
    struct LockedLiquidity {
        uint256 amount;
        uint256 hedgePremium;
        uint256 unhedgePremium;
        bool locked;
    }

    struct Tranche {
        TrancheState state;
        uint256 share;
        uint256 amount;
        uint256 creationTimestamp;
        bool hedged;
    }

    enum TrancheState {Invalid, Open, Closed}

    event Profit(
        uint256 indexed id,
        uint256 hedgeAmount,
        uint256 unhedgeAmount
    );

    event Loss(uint256 indexed id, uint256 hedgeAmount, uint256 unhedgeAmount);

    event Provide(
        address indexed account,
        uint256 amount,
        uint256 writeAmount,
        bool hedging
    );

    event Withdraw(address indexed account, uint256 tranchesID);

    function lock(uint256 amount, uint256 premium)
        external
        returns (uint256 id);

    function unlock(uint256 id) external;

    function send(
        uint256 id,
        address account,
        uint256 amount
    ) external;

    function setLockupPeriod(uint256 value) external;

    function setHedgePool(address value) external;

    function withdraw(uint256 trancheID) external returns (uint256 amount);

    function provideFrom(
        address account,
        uint256 amount,
        bool hedging,
        uint256 minShare
    ) external returns (uint256 share);

    function withdrawWithoutHedge(uint256 trancheID)
        external
        returns (uint256 amount);

    function totalBalance() external view returns (uint256 amount);

    function lockedAmount() external view returns (uint256 amount);

    function token() external view returns (IERC20);

    function lockedLiquidity(uint256 id)
        external
        view
        returns (
            uint256 amount,
            uint256 hedgePremium,
            uint256 unhedgePremium,
            bool locked
        );

    function tranches(uint256 id)
        external
        view
        returns (
            TrancheState state,
            uint256 share,
            uint256 amount,
            uint256 creationTimestamp,
            bool hedged
        );
}

interface IOctiStaking {
    event Claim(address indexed acount, uint256 amount);
    event Profit(uint256 amount);

    function claimProfit() external returns (uint256 profit);

    function buy(uint256 amount) external;

    function sell(uint256 amount) external;

    function sendProfit(uint256 amount) external;

    function profitOf(address account) external view returns (uint256);
}

interface IOctiOptions is IERC721 {
    event Create(
        uint256 indexed id,
        address indexed account,
        uint256 settlementFee,
        uint256 premium
    );

    event Exercise(uint256 indexed id, uint256 profit);
    event Expire(uint256 indexed id);
    enum State {Inactive, Active, Exercised, Expired}
    enum OptionType {Invalid, Put, Call}

    struct Option {
        State state;
        uint256 strike;
        uint256 amount;
        uint256 expiration;
        OptionType optionType;
        uint256 lockedLiquidityID;
    }

    function unlock(uint256) external;

    function createFor(
        address account,
        uint256 period,
        uint256 amount,
        uint256 strike,
        OptionType optionType
    ) external returns (uint256 optionID);

    function options(uint256)
        external
        view
        returns (
            State state,
            uint256 strike,
            uint256 amount,
            uint256 expiration,
            OptionType optionType,
            uint256 lockedLiquidityID
        );

    function priceCalculator() external view returns (IPriceCalculator);
}

interface IPriceCalculator {
    function fees(
        uint256 period,
        uint256 amount,
        uint256 strike,
        IOctiOptions.OptionType optionType
    ) external view returns (uint256 settlementFee, uint256 premium);
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 value) external;
}
