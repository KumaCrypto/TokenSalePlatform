/* eslint-disable prettier/prettier */
/* eslint-disable node/no-unpublished-import */
import { task } from "hardhat/config";

const contractAddress = "0x74fd5dCa8E10f8D4A572D51a01Ce25F5eB57c949";

task("buyToken", "Buy tokens during the sale round")
  .addParam(
    "amountETH",
    "The number of wei for which you want to purchase tokens"
  )
  .setAction(async function (taskArgs, hre) {
    const SalePlatform = await hre.ethers.getContractAt(
      "SalePlatform",
      contractAddress
    );

    await SalePlatform.buyToken({ value: taskArgs.amountETH });
  });
