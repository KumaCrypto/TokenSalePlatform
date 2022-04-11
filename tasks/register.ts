/* eslint-disable prettier/prettier */
/* eslint-disable node/no-unpublished-import */
import { task } from "hardhat/config";

const contractAddress = "0x74fd5dCa8E10f8D4A572D51a01Ce25F5eB57c949";

task("register", "Registration in the referral program")
  .addParam(
    "referrer",
    "The address of the user who invited you,if there is no such address, specify the null address"
  )
  .setAction(async function (taskArgs, hre) {
    const SalePlatform = await hre.ethers.getContractAt(
      "SalePlatform",
      contractAddress
    );

    await SalePlatform.register(taskArgs.referrer);
  });
