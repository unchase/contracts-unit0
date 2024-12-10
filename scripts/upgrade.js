const hre = require("hardhat");
const { ethers, upgrades } = hre;

require("@openzeppelin/hardhat-upgrades");

module.exports = async function () {
  const contractName = `NomisScore`;
  const PROXY_ADDRESS = ``;

  await hre.run("compile");

  // We get the contract to deploy
  const contractFactory = await ethers.getContractFactory(contractName);

  const contract = await upgrades.upgradeProxy(PROXY_ADDRESS, contractFactory, {
    //gasLimit: 11000000,
    //gasPrice: 1629554727,
    timeout: 600000,
    pollingInterval: 5000
  });

  console.log(`Tx hash`, contract.deployTransaction.hash);

  await contract.waitForDeployment();
  console.log(`UpgradeProxy successful! Contract Address:`, contract.target);

  await hre.run("verify:etherscan", {
    address: contract.target,
    constructorArguments: [],
  });

  console.log(`To verify NomisScore: npx hardhat verify --network ${hre.network.name} ${contract.target}`);
};
