import { ethers, run } from "hardhat";
import { BigNumber } from "ethers";

async function main() {
  const [signer] = await ethers.getSigners();

  // Data for example, change for yourself
  const L1RewardSale: number = 5;
  const L2RewardSale: number = 3;
  const tradeReward: number = 3;
  const roundDuration: number = 259200; // 3 days
  const startTokenPrice: BigNumber = ethers.utils.parseEther("0.00001");
  const startTokenAmount: BigNumber = ethers.utils.parseEther("100000");
  const MinterRoleBytes =
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";

  const SALEPLATFORM = await ethers.getContractFactory("SalePlatform");
  const _Token = await ethers.getContractFactory("TestToken");

  const Token = await _Token.deploy();
  await Token.deployed();

  const SalePlatform = await SALEPLATFORM.deploy(
    Token.address,
    roundDuration,
    L1RewardSale,
    L2RewardSale,
    tradeReward,
    startTokenPrice,
    startTokenAmount
  );
  await SalePlatform.deployed();

  await Token.grantRole(MinterRoleBytes, SalePlatform.address);
  await Token.transfer(SalePlatform.address, ethers.utils.parseEther("100000"));

  await run(`verify:verify`, {
    address: Token.address,
    contract: "contracts/TestToken.sol:TestToken",
  });

  await run(`verify:verify`, {
    address: SalePlatform.address,
    contract: "contracts/SalePlatform.sol:SalePlatform",
    constructorArguments: [
      Token.address,
      roundDuration,
      L1RewardSale,
      L2RewardSale,
      tradeReward,
      startTokenPrice,
      startTokenAmount,
    ],
  });

  console.log(`
    Deployed in rinkeby
    =================
    "Platform" contract address: ${SalePlatform.address}
    "Token" contract address: ${Token.address}
    ${signer.address} - deployed this contracts
  `);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
