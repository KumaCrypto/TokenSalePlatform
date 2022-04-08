//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SalePlatform is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    IERC20 public token;
    uint256 public roundTimeDuration;
    Counters.Counter public currentRoundId;

    uint256 public lastTokenPrice;
    RoundType public currentRoundType;

    event registred(address indexed referral, address indexed referrer);

    enum RoundType {
        SALE,
        TRADE
    }

    struct TradeRound {
        uint256 totalTradeVolume;
        uint256 endTime;
        uint256 ordersAmount;
    }

    struct SaleRound {
        // There is already a global variable of the current price,
        // but here it is additionally so that it can be tracked in history.
        uint256 tokenPrice;
        uint256 tokenSupply;
        uint256 endTime;
        uint256 tokensBuyed;
    }

    struct ReferralProgram {
        bool isRegistred;
        address userReferrer;
    }

    mapping(address => ReferralProgram) private referralProgram;

    mapping(uint256 => TradeRound) private tradeRounds;
    mapping(uint256 => SaleRound) private saleRounds;

    constructor(IERC20 _token, uint256 _roundTime) {
        token = _token;
        roundTimeDuration = _roundTime;
    }

    modifier isCorrectRound(RoundType round) {
        require(
            currentRoundType != round,
            "Platform: You cannot start an already running round type"
        );
        _;
    }

    function register(address referrer) external {
        require(
            !referralProgram[msg.sender].isRegistred,
            "Platform: You have already registered"
        );

        if (referrer != address(0)) {
            require(
                referralProgram[referrer].isRegistred,
                "Platform: referrer should be registred"
            );
            referralProgram[msg.sender].userReferrer = referrer;
        }

        referralProgram[msg.sender].isRegistred = true;

        emit registred(msg.sender, referrer);
    }

    function startSaleRound() external isCorrectRound(RoundType.SALE) {

    }

    function startTradeRound() external isCorrectRound(RoundType.TRADE) {
        _startTradeRound();
    }

    function buyToken() external isCorrectRound(RoundType.SALE) {}

    function redeemOrder(uint256 orderId, uint256 amount)
        external
        payable
        nonReentrant
        isCorrectRound(RoundType.TRADE)
    {}

    function removeOrder(uint256 orderId) external {}

    function addOrder(uint256 amount, uint256 priceInETH)
        external
        isCorrectRound(RoundType.TRADE)
    {}

    function _startSaleRound() private {
        currentRoundId.increment();
        lastTokenPrice = calculateNewPrice()
        saleRounds[currentRoundId.current()] = SaleRound();
    }

    function _startTradeRound() private {
        currentRoundId.increment();
        tradeRounds[currentRoundId.current()] = TradeRound(
            0,
            block.timestamp + roundTimeDuration,
            0
        );
        currentRoundType = RoundType.TRADE;
    }

    function calculateNewPrice(uint256 roundId) private view returns (uint256) {
        return (saleRounds[roundId].tokenPrice * 103) / 100 + 4000000000000;
    }

    function calculateNewTokensAmount(uint256 round)
        private
        view
        returns (uint256)
    {
        return tradeRounds[round].totalTradeVolume / lastTokenPrice;
    }
}
