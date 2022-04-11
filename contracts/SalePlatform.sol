//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// This contract can be automated using automatic function call services, such as Gelato.
// Therefore, there are no checks in the contract on whether the time of the round has ended or not,
// but there is only a check on which round is currently underway.

// Error list:
//     ERROR #1 = You cannot call this function in this round;
//     ERROR #2 = The order you are trying to delete does not exist;
//     ERROR #3 = You have already registered;
//     ERROR #4 = Referrer should be registred;
//     ERROR #5 = The last round is not over yet;
//     ERROR #6 = The last round has not ended yet or all tokens have not been sold;
//     ERROR #7 = There are not enough tokens left in this round for your transaction;
//     ERROR #8 = You are trying to buy more tokens than there are in the order;
//     ERROR #9 = You cannot delete this order;

contract SalePlatform is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    address public token;

    Counters.Counter public roundId;
    Counters.Counter public orderId;

    uint256 public roundTimeDuration;
    uint256 public lastTokenPrice;

    uint256 public rewardForL1ReffererInSale;
    uint256 public rewardForL2ReffererInSale;
    uint256 public rewardForRefferersInTrade;

    uint256 public tokensOnSell;

    RoundType public currentRoundType;

    event Registred(address indexed referral, address indexed referrer);
    event SaleRoundEnded(
        uint256 indexed roundId,
        uint256 tokenPrice,
        uint256 tokenSupply,
        uint256 tokensBuyed
    );
    event TradeRoundEnded(
        uint256 indexed roundId,
        uint256 tradeVolume,
        uint256 ordersAmount
    );
    event TokensPurchased(
        address indexed buyer,
        uint256 indexed roundId,
        uint256 tokensAmount
    );
    event OrderAdded(
        address indexed seller,
        uint256 indexed orderId,
        uint256 tokensAmount,
        uint256 tokenPrice
    );
    event OrderRemoved(
        address indexed seller,
        uint256 indexed orderId,
        uint256 tokensWithdrawn,
        uint256 tokenPrice
    );
    event OrderRedeemed(
        address indexed buyer,
        uint256 indexed orderId,
        uint256 tokensAmount,
        uint256 tokenPrice
    );

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

    struct Order {
        address seller;
        uint256 tokensToSell;
        uint256 tokenPrice;
    }

    mapping(address => ReferralProgram) private referralProgram;

    mapping(uint256 => SaleRound) private saleRounds;
    mapping(uint256 => TradeRound) private tradeRounds;
    mapping(uint256 => Order) private orders;

    constructor(
        address _token,
        uint256 _roundTime,
        uint256 saleL1Rewards,
        uint256 saleL2Rewards,
        uint256 tradeReward,
        uint256 startTokenPrice,
        uint256 startTokenAmount
    ) {
        token = _token;
        roundTimeDuration = _roundTime;

        rewardForL1ReffererInSale = saleL1Rewards;
        rewardForL2ReffererInSale = saleL2Rewards;

        rewardForRefferersInTrade = tradeReward;

        // Genesis round for platform.
        saleRounds[0] = SaleRound(
            startTokenPrice,
            startTokenAmount,
            block.timestamp + roundTimeDuration,
            0
        );
        lastTokenPrice = startTokenPrice;
        currentRoundType = RoundType.SALE;
    }

    modifier isCorrectRound(RoundType round) {
        require(currentRoundType == round, "Platform: ERROR #1");
        _;
    }

    modifier isOrderExist(uint256 _orderId) {
        require(_orderId <= orderId.current(), "Platform: ERROR #2");
        _;
    }

    function register(address referrer) external {
        address registering = _msgSender();

        require(
            !referralProgram[registering].isRegistred,
            "Platform: ERROR #3"
        );

        if (referrer != address(0)) {
            require(
                referralProgram[referrer].isRegistred,
                "Platform: ERROR #4"
            );
            referralProgram[registering].userReferrer = referrer;
        }

        referralProgram[registering].isRegistred = true;

        emit Registred(registering, referrer);
    }

    function startSaleRound() external isCorrectRound(RoundType.TRADE) {
        uint256 tradeRoundId = roundId.current();
        TradeRound memory lastTradeRound = tradeRounds[tradeRoundId];

        require(
            lastTradeRound.endTime <= block.timestamp,
            "Platform: ERROR #5"
        );

        _startSaleRound();

        emit TradeRoundEnded(
            tradeRoundId,
            lastTradeRound.totalTradeVolume,
            lastTradeRound.ordersAmount
        );

        // If the trading volume was equal to 0,
        // then we start the next round,
        // since the volume of tokens for sale would be equal to 0.

        if (lastTradeRound.totalTradeVolume == 0) {
            emit SaleRoundEnded(roundId.current(), lastTokenPrice, 0, 0);
            _startTradeRound();
        }
    }

    function startTradeRound() external isCorrectRound(RoundType.SALE) {
        uint256 saleRoundId = roundId.current();
        SaleRound memory lastSaleRound = saleRounds[saleRoundId];

        require(
            lastSaleRound.endTime <= block.timestamp ||
                lastSaleRound.tokenSupply == lastSaleRound.tokensBuyed,
            "Platform: ERROR #6"
        );

        _startTradeRound();

        emit SaleRoundEnded(
            saleRoundId,
            lastSaleRound.tokenPrice,
            lastSaleRound.tokenSupply,
            lastSaleRound.tokensBuyed
        );
    }

    // In the two following functions - there could be checks that msg.value > 0,
    // but in theory, this should not lead to any problems, since there will be 0 in all values, too.
    // The only thing is that users who send 0 wei will have to pay a full commission,
    // as if they have a normal transaction, but on the other hand, we will save on checking for adequate users.

    function buyToken()
        external
        payable
        isCorrectRound(RoundType.SALE)
        nonReentrant
    {
        address buyer = _msgSender();
        uint256 currentRoundId = roundId.current();
        uint256 tokensAmount = calculateTokensAmount(msg.value);
        SaleRound storage currentRound = saleRounds[currentRoundId];

        require(
            tokensAmount <= currentRound.tokenSupply - currentRound.tokensBuyed,
            "Platform: ERROR #7"
        );

        IERC20(token).transfer(buyer, tokensAmount);
        currentRound.tokensBuyed += tokensAmount;

        payToRefferers(buyer);

        emit TokensPurchased(buyer, currentRoundId, tokensAmount);
    }

    function addOrder(uint256 amount, uint256 priceInETH)
        external
        isCorrectRound(RoundType.TRADE)
    {
        address seller = _msgSender();

        IERC20(token).transferFrom(seller, address(this), amount);
        tokensOnSell += amount;

        orderId.increment();
        orders[orderId.current()] = Order(seller, amount, priceInETH);

        tradeRounds[roundId.current()].ordersAmount++;

        emit OrderAdded(seller, orderId.current(), amount, priceInETH);
    }

    function redeemOrder(uint256 _orderId)
        external
        payable
        nonReentrant
        isCorrectRound(RoundType.TRADE)
        isOrderExist(_orderId)
    {
        Order storage currentOrder = orders[_orderId];

        uint256 tokensAmount = msg.value / currentOrder.tokenPrice;
        require(
            currentOrder.tokensToSell >= tokensAmount,
            "Platform: ERROR #8"
        );

        address buyer = _msgSender();
        uint256 amountToSeller = msg.value -
            ((msg.value / 100) * (rewardForRefferersInTrade * 2));

        IERC20(token).transfer(buyer, tokensAmount);

        tokensOnSell -= tokensAmount;
        currentOrder.tokensToSell -= tokensAmount;
        tradeRounds[roundId.current()].totalTradeVolume += msg.value;

        Address.sendValue(payable(currentOrder.seller), amountToSeller);
        payToRefferers(currentOrder.seller);

        emit OrderRedeemed(
            buyer,
            _orderId,
            tokensAmount,
            currentOrder.tokenPrice
        );
    }

    function removeOrder(uint256 _orderId)
        external
        isCorrectRound(RoundType.TRADE)
        isOrderExist(_orderId)
    {
        Order memory currentOrder = orders[_orderId];

        // Either the order has already been deleted,
        // or the caller is not the owner of this order
        require(currentOrder.seller == _msgSender(), "Platform: ERROR #9");

        // It makes no sense to leave information about the order in storage,
        // since after assigning tokensToSell = 0, the rest of the information does not seem important.
        // And everything you need can be viewed in the event.
        // Therefore, in order to save gas, we delete the order from storage.
        delete orders[_orderId];

        if (currentOrder.tokensToSell != 0) {
            IERC20(token).transfer(
                currentOrder.seller,
                currentOrder.tokensToSell
            );
            tokensOnSell -= currentOrder.tokensToSell;
        }

        emit OrderRemoved(
            currentOrder.seller,
            _orderId,
            currentOrder.tokensToSell,
            currentOrder.tokenPrice
        );
    }

    // Private functions
    function _startSaleRound() private {
        uint256 newTokensAmount = calculateTokensAmount(
            tradeRounds[roundId.current()].totalTradeVolume
        );

        lastTokenPrice = calculateNewPrice();

        roundId.increment();

        saleRounds[roundId.current()] = SaleRound(
            lastTokenPrice,
            newTokensAmount,
            block.timestamp + roundTimeDuration,
            0
        );

        currentRoundType = RoundType.SALE;

        IToken(token).mint(address(this), newTokensAmount);
    }

    function _startTradeRound() private {
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance > 0) {
            IToken(token).burn(balance - tokensOnSell);
        }

        roundId.increment();
        tradeRounds[roundId.current()] = TradeRound(
            0,
            block.timestamp + roundTimeDuration,
            0
        );

        currentRoundType = RoundType.TRADE;
    }

    function payToRefferers(address seller) private {
        address l1Refferer = referralProgram[seller].userReferrer;

        if (currentRoundType == RoundType.SALE) {
            if (l1Refferer != address(0)) {
                Address.sendValue(
                    payable(l1Refferer),
                    (msg.value / 100) * rewardForL1ReffererInSale
                );

                address l2Refferer = referralProgram[l1Refferer].userReferrer;
                if (l2Refferer != address(0)) {
                    Address.sendValue(
                        payable(l2Refferer),
                        (msg.value / 100) * rewardForL2ReffererInSale
                    );
                }
            }
        } else {
            if (l1Refferer != address(0)) {
                Address.sendValue(
                    payable(l1Refferer),
                    (msg.value / 100) * rewardForRefferersInTrade
                );

                address l2Refferer = referralProgram[l1Refferer].userReferrer;
                if (l2Refferer != address(0)) {
                    Address.sendValue(
                        payable(l2Refferer),
                        (msg.value / 100) * rewardForRefferersInTrade
                    );
                }
            }
        }
    }

    // Utils functions for calculating new values
    function calculateNewPrice() private view returns (uint256) {
        return (lastTokenPrice * 103) / 100 + 4000000000000;
    }

    function calculateTokensAmount(uint256 value)
        private
        view
        returns (uint256)
    {
        return (value / lastTokenPrice) * 10**18;
    }

    // Getters
    function getUserReferrer(address _user) external view returns (address) {
        return referralProgram[_user].userReferrer;
    }

    function isUserRegistred(address _user) external view returns (bool) {
        return referralProgram[_user].isRegistred;
    }

    function getTokensBuyed(uint256 _roundId) external view returns (uint256) {
        return saleRounds[_roundId].tokensBuyed;
    }

    function getSaleRoundEndTime(uint256 _roundId)
        external
        view
        returns (uint256)
    {
        return saleRounds[_roundId].endTime;
    }

    function getSaleRoundTokenSupply(uint256 _roundId)
        external
        view
        returns (uint256)
    {
        return saleRounds[_roundId].tokenSupply;
    }

    function getTotalTradeVolume(uint256 _roundId)
        external
        view
        returns (uint256)
    {
        return tradeRounds[_roundId].totalTradeVolume;
    }

    function getTradeRoundEndTime(uint256 _roundId)
        external
        view
        returns (uint256)
    {
        return tradeRounds[_roundId].endTime;
    }

    function getTradeRoundOrdersAmount(uint256 _roundId)
        external
        view
        returns (uint256)
    {
        return tradeRounds[_roundId].ordersAmount;
    }

    function getSellerOfOrder(uint256 _orderId)
        external
        view
        returns (address)
    {
        return orders[_orderId].seller;
    }

    function getOrderTokenPrice(uint256 _orderId)
        external
        view
        returns (uint256)
    {
        return orders[_orderId].tokenPrice;
    }

    function getOrderTokensAmount(uint256 _orderId)
        external
        view
        returns (uint256)
    {
        return orders[_orderId].tokensToSell;
    }
}
