/* eslint-disable prettier/prettier */
/* eslint-disable node/no-missing-import */
/* eslint-disable camelcase */

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

import {
  SalePlatform,
  SalePlatform__factory,
  TestToken,
  TestToken__factory,
} from "../typechain-types";

describe("TokenSalePlatform", function () {
  let signers: SignerWithAddress[];
  let SalePlatform: SalePlatform;
  let Token: TestToken;

  const L1RewardSale: number = 5;
  const L2RewardSale: number = 3;
  const tradeReward: number = 3;
  const roundDuration: number = 259200; // 3 days
  const startTokenPrice: BigNumber = ethers.utils.parseEther("0.00001");
  const startTokenAmount: BigNumber = ethers.utils.parseEther("100000");
  const RoundSale: number = 0;
  const RoundTrade: number = 1;
  const defaultAmount: number = 1000;
  const zeroAddress: string = ethers.constants.AddressZero;
  const MinterRoleBytes =
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";

  beforeEach(async function () {
    signers = await ethers.getSigners();

    Token = await new TestToken__factory(signers[0]).deploy();
    SalePlatform = await new SalePlatform__factory(signers[0]).deploy(
      Token.address,
      roundDuration,
      L1RewardSale,
      L2RewardSale,
      tradeReward,
      startTokenPrice,
      startTokenAmount
    );

    await Token.grantRole(MinterRoleBytes, SalePlatform.address);

    await Token.transfer(
      SalePlatform.address,
      ethers.utils.parseEther("100000")
    );
  });

  describe("Checking getters", () => {
    it("getToken", async () => {
      expect(await SalePlatform.token()).to.eq(Token.address);
    });

    it("getRoundTimeDuration", async () => {
      expect(await SalePlatform.roundTimeDuration()).to.eq(roundDuration);
    });

    it("getRoundId", async () => {
      expect(await SalePlatform.roundId()).to.eq(0);
    });

    it("getLastTokenPrice", async () => {
      expect(await SalePlatform.lastTokenPrice()).to.eq(
        ethers.utils.parseEther("0.00001")
      );
    });

    it("getCurrentRoundType", async () => {
      expect(await SalePlatform.currentRoundType()).to.eq(RoundSale);
    });

    it("startBalanceIsCorrect", async () => {
      expect(await Token.balanceOf(SalePlatform.address)).to.eq(
        ethers.utils.parseEther("100000")
      );
    });

    it("getSaleRoundEndTime", async () => {
      const time =
        (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
          .timestamp +
        roundDuration -
        2;
      const saleEndTime = await SalePlatform.saleRounds(0);
      expect(saleEndTime[2]).to.eq(time);
    });

    it("getSaleRoundTokenSupply", async () => {
      const tokenSupply = await SalePlatform.saleRounds(0);
      expect(tokenSupply[1]).to.eq(ethers.utils.parseEther("100000"));
    });

    it("getTradeRoundEndTime", async () => {
      await ethers.provider.send("evm_increaseTime", [roundDuration]);
      await SalePlatform.startTradeRound();

      const time =
        (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
          .timestamp + roundDuration;
      const endTime = await SalePlatform.tradeRounds(1);
      expect(endTime[1]).to.eq(time);
    });
  });

  describe("modifiers", () => {
    it("isCorrectRound", async () => {
      await expect(SalePlatform.startSaleRound()).to.be.revertedWith(
        "Platform: ERROR #1"
      );
    });

    it("isOrderExist", async () => {
      await ethers.provider.send("evm_increaseTime", [roundDuration]);
      await SalePlatform.startTradeRound();

      await expect(SalePlatform.removeOrder(1)).to.be.revertedWith(
        "Platform: ERROR #2"
      );
    });
  });

  describe("register", () => {
    it("register: Is User Registred", async () => {
      await SalePlatform.register(zeroAddress);
      const bio = await SalePlatform.referralProgram(signers[0].address);
      expect(bio[0]).to.eq(true);
    });

    it("register: Referrer is correct", async () => {
      await SalePlatform.register(zeroAddress);
      await SalePlatform.connect(signers[1]).register(signers[0].address);

      const bio = await SalePlatform.referralProgram(signers[1].address);
      expect(bio[1]).to.eq(signers[0].address);
    });

    it("register: Reverted - already registred", async () => {
      await SalePlatform.register(zeroAddress);

      await expect(SalePlatform.register(zeroAddress)).to.be.revertedWith(
        "Platform: ERROR #3"
      );
    });

    it("register: Reverted - referrer isn't registred", async () => {
      await expect(
        SalePlatform.register(signers[1].address)
      ).to.be.revertedWith("Platform: ERROR #4");
    });

    it("register: To emit Registred", async () => {
      expect(await SalePlatform.register(zeroAddress))
        .to.emit(SalePlatform, "Registred")
        .withArgs(signers[0].address, zeroAddress);
    });
  });

  describe("startTradeRound - require", () => {
    it("startTradeRound: Reverted - last round has not ended", async () => {
      await expect(SalePlatform.startTradeRound()).to.be.revertedWith(
        "Platform: ERROR #6"
      );
    });
  });

  describe("startTradeRound", () => {
    beforeEach(async function () {
      await ethers.provider.send("evm_increaseTime", [roundDuration]);
    });

    it("startTradeRound: Changed RoundId", async () => {
      const roundId = await SalePlatform.roundId();
      await SalePlatform.startTradeRound();
      expect(roundId.add(1)).to.eq(await SalePlatform.roundId());
    });

    it("startTradeRound: Changed RoundType", async () => {
      await SalePlatform.startTradeRound();
      expect(await SalePlatform.currentRoundType()).to.eq(1);
    });

    it("startTradeRound: All tokens are burned", async () => {
      await SalePlatform.startTradeRound();
      expect(await Token.balanceOf(SalePlatform.address)).to.eq(
        BigNumber.from("0")
      );
    });

    it("startTradeRound: To emit SaleRoundEnded", async () => {
      await expect(SalePlatform.startTradeRound())
        .to.emit(SalePlatform, "SaleRoundEnded")
        .withArgs(0, startTokenPrice, startTokenAmount, 0);
    });
  });

  describe("startSaleRound - require", () => {
    it("startSaleRound: Reverted - isn't a trade round", async () => {
      await expect(SalePlatform.startSaleRound()).to.be.revertedWith(
        "Platform: ERROR #1"
      );
    });

    it("startSaleRound: Reverted - last round is not over yet", async () => {
      await ethers.provider.send("evm_increaseTime", [roundDuration]);
      await SalePlatform.startTradeRound();
      await expect(SalePlatform.startSaleRound()).to.be.revertedWith(
        "Platform: ERROR #5"
      );
    });
  });

  describe("startSaleRound", () => {
    beforeEach(async function () {
      await Token.approve(SalePlatform.address, defaultAmount);

      await ethers.provider.send("evm_increaseTime", [roundDuration]);

      await SalePlatform.buyToken({ value: ethers.utils.parseEther("0.1") });
      await SalePlatform.startTradeRound();

      await ethers.provider.send("evm_increaseTime", [roundDuration]);
    });

    it("startSaleRound: TradeVolume = 0 => tradeRound", async () => {
      await SalePlatform.startSaleRound();
      expect(await SalePlatform.currentRoundType()).to.eq(RoundTrade);
    });

    it("startSaleRound: To emit SaleRoundEnded if trade volume = 0", async () => {
      await expect(SalePlatform.startSaleRound()).to.emit(
        SalePlatform,
        "SaleRoundEnded"
      );
    });

    it("startSaleRound: Changed RoundId", async () => {
      const roundId = await SalePlatform.roundId();

      await SalePlatform.addOrder(defaultAmount, 1);
      await SalePlatform.redeemOrder(1, { value: defaultAmount });

      await SalePlatform.startSaleRound();
      expect(roundId.add(1)).to.eq(await SalePlatform.roundId());
    });

    it("startSaleRound: Changed RoundType", async () => {
      await SalePlatform.addOrder(defaultAmount, 1);
      await SalePlatform.redeemOrder(1, { value: defaultAmount });

      await SalePlatform.startSaleRound();
      expect(await SalePlatform.currentRoundType()).to.eq(RoundSale);
    });

    it("startSaleRound: The price has changed", async () => {
      const newTokenPrice = "14300000000000";
      await SalePlatform.startSaleRound();
      expect((await SalePlatform.lastTokenPrice()).toString()).to.eq(
        newTokenPrice
      );
    });
  });

  describe("buyToken", () => {
    const Value = ethers.utils.parseEther("0.1");
    const l1Reward = ethers.utils.parseEther("0.005");
    const l2Reward = ethers.utils.parseEther("0.003");

    it("buyToken: msg.value = 0 => reverted", async () => {
      await expect(SalePlatform.buyToken({ value: 0 })).to.be.revertedWith(
        "Platform ERROR #10"
      );
    });

    it("buyToken: msg.value is too high => reverted", async () => {
      await expect(
        SalePlatform.buyToken({ value: ethers.utils.parseEther("1.1") })
      ).to.be.revertedWith("Platform: ERROR #7");
    });

    it("buyToken: The buyer received his tokens", async () => {
      await expect(
        await SalePlatform.buyToken({ value: Value })
      ).to.changeEtherBalance(signers[0], Value.sub(Value.mul(2)));
    });

    it("buyToken: TokensBuyed increased", async () => {
      await SalePlatform.buyToken({ value: Value });
      const tokensBuyed = await SalePlatform.saleRounds(0);
      expect(tokensBuyed[3]).to.eq(ethers.utils.parseEther("10000"));
    });

    it("buyToken: To emit 'TokensPurchased'", async () => {
      await expect(SalePlatform.buyToken({ value: Value }))
        .to.emit(SalePlatform, "TokensPurchased")
        .withArgs(signers[0].address, 0, ethers.utils.parseEther("10000"));
    });

    it("buyToken: Paid to L1 referr", async () => {
      await SalePlatform.connect(signers[1]).register(zeroAddress);
      await SalePlatform.register(signers[1].address);

      await expect(
        await SalePlatform.buyToken({ value: Value })
      ).to.changeEtherBalance(signers[1], l1Reward);
    });

    it("buyToken: Paid to L2 referr", async () => {
      await SalePlatform.connect(signers[2]).register(zeroAddress);
      await SalePlatform.connect(signers[1]).register(signers[2].address);
      await SalePlatform.register(signers[1].address);

      await expect(
        await SalePlatform.buyToken({ value: Value })
      ).to.changeEtherBalance(signers[2], l2Reward);
    });
  });

  describe("addOrder", () => {
    beforeEach(async function () {
      await Token.approve(SalePlatform.address, defaultAmount);
      await SalePlatform.buyToken({ value: ethers.utils.parseEther("1") });

      await ethers.provider.send("evm_increaseTime", [roundDuration]);
      await SalePlatform.startTradeRound();
    });

    it("addOrder: Tokens have been debited from the seller", async () => {
      const balanceBefore = await Token.balanceOf(signers[0].address);
      await SalePlatform.addOrder(defaultAmount, 1);
      const balanceAfter = await Token.balanceOf(signers[0].address);

      expect(balanceBefore.sub(defaultAmount)).to.eq(balanceAfter);
    });

    it("addOrder: Increased tokensOnSell ", async () => {
      await SalePlatform.addOrder(defaultAmount, 1);
      expect(await SalePlatform.tokensOnSell()).to.eq(defaultAmount);
    });

    it("addOrder: The order is added to the orders", async () => {
      await SalePlatform.addOrder(defaultAmount, 1);
      const order = await SalePlatform.orders(1);

      expect(order[0]).to.eq(signers[0].address);
      expect(order[2]).to.eq(1);
      expect(order[1]).to.eq(defaultAmount);
    });

    it("addOrder: Increased the number of orders", async () => {
      await SalePlatform.addOrder(defaultAmount, 1);
      const tradeRound = await SalePlatform.tradeRounds(1);
      expect(tradeRound[2]).to.eq(1);
    });

    it("addOrder: To emit OrderAdded ", async () => {
      await expect(SalePlatform.addOrder(defaultAmount, 1))
        .to.emit(SalePlatform, "OrderAdded")
        .withArgs(signers[0].address, 1, defaultAmount, 1);
    });
  });

  describe("redeemOrder", () => {
    beforeEach(async function () {
      await Token.approve(SalePlatform.address, defaultAmount);
      await SalePlatform.buyToken({ value: ethers.utils.parseEther("1") });

      await ethers.provider.send("evm_increaseTime", [roundDuration]);

      await SalePlatform.startTradeRound();
      await SalePlatform.addOrder(defaultAmount, 1);
    });

    it("redeemOrder: Require - too large msg.value", async () => {
      const Value = ethers.utils.parseEther("10");
      await expect(
        SalePlatform.redeemOrder(1, { value: Value })
      ).to.be.revertedWith("Platform: ERROR #8");
    });

    it("redeemOrder: msg.value = 0 => reverted", async () => {
      await expect(
        SalePlatform.redeemOrder(1, { value: 0 })
      ).to.be.revertedWith("Platform ERROR #10");
    });

    it("redeemOrder: transfered correct token amount", async () => {
      const balanceBefore = await Token.balanceOf(signers[0].address);

      await SalePlatform.redeemOrder(1, { value: defaultAmount });

      const balanceAfter = await Token.balanceOf(signers[0].address);
      expect(balanceBefore.add(defaultAmount)).to.eq(balanceAfter);
    });

    it("redeemOrder: Reduce tokensOnSell", async () => {
      await SalePlatform.redeemOrder(1, { value: defaultAmount });

      expect(await SalePlatform.tokensOnSell()).to.eq(0);
    });

    it("redeemOrder: Reduce tokensAmount", async () => {
      await SalePlatform.redeemOrder(1, { value: defaultAmount });
      const order = await SalePlatform.orders(1);
      expect(order[1]).to.eq(0);
    });

    it("redeemOrder: Increased totalTradeVolume", async () => {
      await SalePlatform.redeemOrder(1, { value: defaultAmount });
      const tradeRound = await SalePlatform.tradeRounds(1);
      expect(tradeRound[0]).to.eq(defaultAmount);
    });

    it("redeemOrder: sent a correct value to seller without a referrs", async () => {
      await expect(
        await SalePlatform.connect(signers[1]).redeemOrder(1, {
          value: defaultAmount,
        })
      ).to.changeEtherBalance(signers[0], 940);
    });

    it("redeemOrder: The correct value was sent to L1 reffer", async () => {
      await SalePlatform.connect(signers[1]).register(zeroAddress);
      await SalePlatform.register(signers[1].address);

      await expect(
        await SalePlatform.connect(signers[3]).redeemOrder(1, {
          value: defaultAmount,
        })
      ).to.changeEtherBalance(signers[1], 30);
    });

    it("redeemOrder: The correct value was sent to L2 reffer", async () => {
      await SalePlatform.connect(signers[2]).register(zeroAddress);
      await SalePlatform.connect(signers[1]).register(signers[2].address);
      await SalePlatform.register(signers[1].address);

      await expect(
        await SalePlatform.connect(signers[3]).redeemOrder(1, {
          value: defaultAmount,
        })
      ).to.changeEtherBalance(signers[2], 30);
    });

    it("redeemOrder: To emit OrderRedeemed", async () => {
      await expect(SalePlatform.redeemOrder(1, { value: defaultAmount }))
        .to.emit(SalePlatform, "OrderRedeemed")
        .withArgs(signers[0].address, 1, defaultAmount, 1);
    });
  });

  describe("removeOrder", () => {
    beforeEach(async function () {
      await Token.approve(SalePlatform.address, defaultAmount);
      await SalePlatform.buyToken({ value: ethers.utils.parseEther("1") });

      await ethers.provider.send("evm_increaseTime", [roundDuration]);
      await SalePlatform.startTradeRound();
      await SalePlatform.addOrder(defaultAmount, 1);
    });

    it("removeOrder: Require - not the owner of the order", async () => {
      await expect(
        SalePlatform.connect(signers[1]).removeOrder(1)
      ).to.be.revertedWith("Platform: ERROR #9");
    });

    it("removeOrder: Order deleted", async () => {
      await SalePlatform.removeOrder(1);
      const order = await SalePlatform.orders(1);

      expect(order[0]).to.eq(zeroAddress);
      expect(order[2]).to.eq(0);
      expect(order[1]).to.eq(0);
    });

    it("removeOrder: If path", async () => {
      await SalePlatform.redeemOrder(1, { value: defaultAmount });
      await SalePlatform.removeOrder(1);
      const order = await SalePlatform.orders(1);

      expect(order[0]).to.eq(zeroAddress);
      expect(order[2]).to.eq(0);
      expect(order[1]).to.eq(0);
    });

    it("removeOrder: Return tokens", async () => {
      const balanceBefore = await Token.balanceOf(signers[0].address);
      await SalePlatform.removeOrder(1);
      const balanceAfter = await Token.balanceOf(signers[0].address);

      expect(balanceBefore.add(defaultAmount)).to.eq(balanceAfter);
    });

    it("removeOrder: Decrement tokensOnSell", async () => {
      const tokensOnsell = await SalePlatform.tokensOnSell();
      await SalePlatform.removeOrder(1);
      expect(tokensOnsell.sub(defaultAmount)).to.eq(
        await SalePlatform.tokensOnSell()
      );
    });

    it("removeOrder: To emit OrderRemoved", async () => {
      await expect(SalePlatform.removeOrder(1))
        .to.emit(SalePlatform, "OrderRemoved")
        .withArgs(signers[0].address, 1, defaultAmount, 1);
    });
  });
  
  describe("withdraw", () => {
    const Value = ethers.utils.parseEther("1");
    beforeEach(async function () {
      await Token.approve(SalePlatform.address, defaultAmount);
      await SalePlatform.buyToken({ value: Value });
    });

    it("withdraw: Require - value is too large", async () => {
      await expect(
        SalePlatform.withdraw(signers[0].address, ethers.utils.parseEther("2"))
      ).to.be.revertedWith("Platform: ERROR #11");
    });
    it("withdraw: Accrues the specified value", async () => {
      await expect(
        await SalePlatform.withdraw(signers[0].address, Value)
      ).to.changeEtherBalance(signers[0], Value);
    });
  });
  
});
