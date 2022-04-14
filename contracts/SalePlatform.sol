//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
//     ERROR #10 = The amount of ETH sent must be greater than 0;

contract SalePlatform is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public token;

    uint256 public roundId;
    uint256 public orderId;

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
        address payable userReferrer;
    }

    struct Order {
        address payable seller;
        uint256 tokensToSell;
        uint256 tokenPrice;
    }

    mapping(address => ReferralProgram) public referralProgram;

    mapping(uint256 => SaleRound) public saleRounds;
    mapping(uint256 => TradeRound) public tradeRounds;
    mapping(uint256 => Order) public orders;

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
        require(_orderId <= orderId, "Platform: ERROR #2");
        _;
    }

    function register(address payable referrer) external {
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
        TradeRound memory lastTradeRound = tradeRounds[roundId];

        require(
            lastTradeRound.endTime <= block.timestamp,
            "Platform: ERROR #5"
        );

        _startSaleRound();

        emit TradeRoundEnded(
            roundId - 1,
            lastTradeRound.totalTradeVolume,
            lastTradeRound.ordersAmount
        );

        // If the trading volume was equal to 0,
        // then we start the next round,
        // since the volume of tokens for sale would be equal to 0.

        if (lastTradeRound.totalTradeVolume == 0) {
            emit SaleRoundEnded(roundId, lastTokenPrice, 0, 0);
            _startTradeRound();
        }
    }

    function startTradeRound() external isCorrectRound(RoundType.SALE) {
        SaleRound memory lastSaleRound = saleRounds[roundId];

        require(
            lastSaleRound.endTime <= block.timestamp ||
                lastSaleRound.tokenSupply == lastSaleRound.tokensBuyed,
            "Platform: ERROR #6"
        );

        _startTradeRound();

        emit SaleRoundEnded(
            roundId - 1,
            lastSaleRound.tokenPrice,
            lastSaleRound.tokenSupply,
            lastSaleRound.tokensBuyed
        );
    }

    function buyToken()
        external
        payable
        isCorrectRound(RoundType.SALE)
        nonReentrant
    {
        require(msg.value > 0, "Platform ERROR #10");

        address buyer = _msgSender();
        uint256 tokensAmount = calculateTokensAmount(msg.value);
        SaleRound storage currentRound = saleRounds[roundId];

        require(
            tokensAmount <= currentRound.tokenSupply - currentRound.tokensBuyed,
            "Platform: ERROR #7"
        );

        IERC20(token).transfer(buyer, tokensAmount);
        currentRound.tokensBuyed = currentRound.tokensBuyed + tokensAmount;

        payToRefferers(buyer);

        emit TokensPurchased(buyer, roundId, tokensAmount);
    }

    function addOrder(uint256 amount, uint256 priceInETH)
        external
        isCorrectRound(RoundType.TRADE)
    {
        address payable seller = payable(_msgSender());

        IERC20(token).transferFrom(seller, address(this), amount);
        tokensOnSell = tokensOnSell + amount;

        orderId++;
        orders[orderId] = Order(seller, amount, priceInETH);

        tradeRounds[roundId].ordersAmount++;

        emit OrderAdded(seller, orderId, amount, priceInETH);
    }

    function redeemOrder(uint256 _orderId)
        external
        payable
        nonReentrant
        isCorrectRound(RoundType.TRADE)
        isOrderExist(_orderId)
    {
        require(msg.value > 0, "Platform ERROR #10");

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

        tokensOnSell = tokensOnSell - tokensAmount;
        currentOrder.tokensToSell = currentOrder.tokensToSell - tokensAmount;
        tradeRounds[roundId].totalTradeVolume =
            tradeRounds[roundId].totalTradeVolume +
            msg.value;

        currentOrder.seller.sendValue(amountToSeller);
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
            tokensOnSell = tokensOnSell - currentOrder.tokensToSell;
        }

        emit OrderRemoved(
            currentOrder.seller,
            _orderId,
            currentOrder.tokensToSell,
            currentOrder.tokenPrice
        );
    }
    
    function withdraw(address payable to, uint amount) external onlyOwner {
        require(address(this).balance >= amount, "Platform: ERROR #11");
        to.sendValue(amount);
    }

    // Private functions
    function _startSaleRound() private {
        uint256 newTokensAmount = calculateTokensAmount(
            tradeRounds[roundId].totalTradeVolume
        );

        lastTokenPrice = calculateNewPrice();

        roundId++;

        saleRounds[roundId] = SaleRound(
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

        roundId++;
        tradeRounds[roundId] = TradeRound(
            0,
            block.timestamp + roundTimeDuration,
            0
        );

        currentRoundType = RoundType.TRADE;
    }

    function payToRefferers(address seller) private {
        address payable l1Refferer = referralProgram[seller].userReferrer;

        if (currentRoundType == RoundType.SALE) {
            if (l1Refferer != address(0)) {
                l1Refferer.sendValue(
                    (msg.value / 100) * rewardForL1ReffererInSale
                );

                address payable l2Refferer = referralProgram[l1Refferer]
                    .userReferrer;
                if (l2Refferer != address(0)) {
                    l2Refferer.sendValue(
                        (msg.value / 100) * rewardForL2ReffererInSale
                    );
                }
            }
        } else {
            if (l1Refferer != address(0)) {
                l1Refferer.sendValue(
                    (msg.value / 100) * rewardForRefferersInTrade
                );

                address payable l2Refferer = referralProgram[l1Refferer]
                    .userReferrer;
                if (l2Refferer != address(0)) {
                    l2Refferer.sendValue(
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
}
