/* eslint-disable prettier/prettier */
/* eslint-disable node/no-unpublished-import */
import { task } from "hardhat/config";

const contractAddress = "0x74fd5dCa8E10f8D4A572D51a01Ce25F5eB57c949";

task("redeemOrder", "Buy tokens from the user")
  .addParam("orderId", "From which order do you want to buy tokens")
  .setAction(async function (taskArgs, hre) {
    const SalePlatform = await hre.ethers.getContractAt(
      "SalePlatform",
      contractAddress
    );

    await SalePlatform.redeemOrder(taskArgs.orderId);
  });
