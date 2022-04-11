/* eslint-disable prettier/prettier */
/* eslint-disable node/no-unpublished-import */
import { task } from "hardhat/config";

const contractAddress = "0x74fd5dCa8E10f8D4A572D51a01Ce25F5eB57c949";

task("removeOrder", "Delete your existing order and return tokens")
  .addParam("orderId", "Which order do you want to delete")
  .setAction(async function (taskArgs, hre) {
    const SalePlatform = await hre.ethers.getContractAt(
      "SalePlatform",
      contractAddress
    );

    await SalePlatform.removeOrder(taskArgs.OrderId);
  });
