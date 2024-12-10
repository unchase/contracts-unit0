const hre = require("hardhat");

async function main() {
  const contractName = `BalanceChecker`;

  await hre.run("compile");

  const contract = await hre.ethers.deployContract(contractName, []);

  console.log(`BalanceChecker tx hash`, contract.deploymentTransaction().hash);

  console.log(`Star waiting...`);
  await contract.waitForDeployment();
  await contract.deploymentTransaction().wait(2);

  console.log(
    `Deployment "${contractName}" successful! Contract Address:`,
    contract.target
  );

  await hre.run("verify:etherscan", {
    address: contract.target,
    constructorArguments: [],
  });

  console.log(
    `To verify "${contractName}": npx hardhat verify --network ${hre.network.name} ${contract.target}`
  );
}

module.exports = main;
