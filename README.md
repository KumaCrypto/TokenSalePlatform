# A platform for selling tokens.

## Description:

There are 2 rounds of "Trade" and "Sale", which follow each other, starting with the sale round.
Each round lasts X days.

### Basic concepts:

"Sale" round - In this round, the user can buy tokens at a fixed price from the platform for ETH.
"Trade" round - in this round, users can buy tokens from each other for ETH.
Referral program — The referral program has two levels, users receive rewards in ETH.

### Description of the "Sale" round:

The price of the token increases with each round and is calculated according to the formula. The number of tokens issued in each Sale round is different and depends on the total trading volume in the "Trade" round. The round may end prematurely if all tokens have been sold out. At the end of the round, all open orders are transferred to the next Trade round, if they are not withdrawn or redeemed in the next round, they are transferred again. The very first round sells tokens worth X ETH (X tokens).

Calculation example:
trading volume in the trade round = 0.5 ETH (the total amount of ETH for which users traded within one trade round)
0,5 / 0,0000187 = 26737.96. (0,0000187 = the price of the token in the current round)
therefore, 26737.96 tokens will be available for sale in the Sale round.

### Description of the "Trade" round:

user_1 places an order to sell tokens for a certain amount in ETH. User_2 buys tokens for ETH. The order may not be fully redeemed. Also, the order can be revoked and the user will get back his tokens that have not been sold yet. The received ETH is immediately sent to the user in their metamask wallet. At the end of the round, all open orders are closed and the remaining tokens are sent to their owners.

### Description of the Referral program:

When registering, the user specifies his referrer (the referrer must already be registered on the platform).
When buying tokens in the Sale round, referrer_1 will receive X% of its purchase, referrer_2 will receive X%, the platform itself will receive X% in the absence of referrers, the platform receives everything.
When buying in the Trade round, the user who placed an order for the sale of tokens will receive X% ETH and referrers will receive X%, in case of their absence, the platform takes these percentages for itself.

Price ETH = lastPrice \* 1,03 + 0,000004

- Example of token price calculation: 0,0000100 \* 1,03 + 0,000004 = 0.0000143

### Disclaimer

The code in this repository is provided for educational purposes only. The code has not been audited. By using this code, you take full responsibility for possible errors and their consequences.

### Deployed in rinkeby:

| Contracts | Addresses                                  |
| --------- | ------------------------------------------ |
| Platfrom  | 0x74fd5dCa8E10f8D4A572D51a01Ce25F5eB57c949 |
| TestToken | 0xDA8899ca92FEf91d288586bDd08B597aeBFE06E9 |

#### Coverage:

| File             | % Stmts | % Branch | % Funcs | % Lines | Uncovered Lines |
| ---------------- | ------- | -------- | ------- | ------- | --------------- |
| contracts\       | 100     | 100      | 100     | 100     |                 |
| IToken.sol       | 100     | 100      | 100     | 100     |                 |
| SalePlatform.sol | 100     | 100      | 100     | 100     |                 |
| TestToken.sol    | 100     | 100      | 100     | 100     |                 |
| All files        | 100     | 100      | 100     | 100     |                 |
