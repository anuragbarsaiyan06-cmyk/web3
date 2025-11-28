const { ethers } = require("hardhat");

async function main() {
  const ChainYieldProtocol = await ethers.getContractFactory("ChainYieldProtocol");
  const chainYieldProtocol = await ChainYieldProtocol.deploy();

  await chainYieldProtocol.deployed();

  console.log("ChainYieldProtocol contract deployed to:", chainYieldProtocol.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
