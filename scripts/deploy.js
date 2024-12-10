const hre = require("hardhat");
const { ethers, upgrades } = hre;

require("@openzeppelin/hardhat-upgrades");

async function main() {
  const contractName = `NomisScore`;
  const props = [0, 24];

  await hre.run("compile");

  // We get the contract to deploy
  const contractFactory = await ethers.getContractFactory(contractName);

  const contract = await upgrades.deployProxy(contractFactory, [...props], {
    initializer: "initialize",
    //gasLimit: 4000000,
    gasPrice: 700000000000000,
    timeout: 600000,
    pollingInterval: 5000,
  });

  console.log(`NomisScore tx hash`, contract.deploymentTransaction().hash);

  console.log(`Star waiting...`);
  await contract.waitForDeployment();
  const tx = await contract.deploymentTransaction().wait(2);

  console.log(`Deployment Gas Used: ${tx.cumulativeGasUsed.toString()}`);

  await hre.run("verify:etherscan", {
    address: contract.target,
    constructorArguments: [],
  });

  console.log(
    `Deployment "${contractName}" successful! Contract Address:`,
    contract.target
  );
  console.log(
    `To verify NomisScore: npx hardhat verify --network ${hre.network.name} ${contract.target}`
  );
}

module.exports = main;
