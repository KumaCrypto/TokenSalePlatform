/* eslint-disable prettier/prettier */
/* eslint-disable node/no-unpublished-import */
import { task } from "hardhat/config";

const contractAddress = "0x74fd5dCa8E10f8D4A572D51a01Ce25F5eB57c949";

task("addOrder", "Put tokens up for sale during a trade round")
  .addParam("amount", "Number of tokens for sale")
  .addParam("priceInETH", "Price per token")
  .setAction(async function (taskArgs, hre) {
    const SalePlatform = await hre.ethers.getContractAt(
      "SalePlatform",
      contractAddress
    );

    await SalePlatform.addOrder(taskArgs.amount, taskArgs.priceInETH);
  });
