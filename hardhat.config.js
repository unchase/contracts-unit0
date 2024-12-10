const { task } = require("hardhat/config");

require("dotenv").config();

require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("@openzeppelin/hardhat-upgrades");

task("deploy", "Deploy contract").setAction(async () => {
  const deploy = require("./scripts/deploy");
  await deploy();
});

task("upgrade", "Upgrade contract").setAction(async () => {
  const upgrade = require("./scripts/upgrade");
  await upgrade();
});

task("deploy-checker", "Deploy BalanceChecker contract").setAction(async () => {
  const deploy = require("./scripts/deploy-checker");
  await deploy();
});

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "unitzero",
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    unitzero: {
      chainId: 88811,
      url: "https://rpc.unit0.dev",
      accounts: [process.env.PRIVATE_KEY],
      gasMultiplier: 4,
    },
  },
  etherscan: {
    apiKey: {
      unitzero: process.env.unitzero_API_KEY,
    },
    customChains: [
      {
        network: "unitzero",
        chainId: 88811,
        urls: {
          apiURL: "https://explorer.unit0.dev/api",
          browserURL: "https://explorer.unit0.dev",
        },
      },
    ],
  },
  sourcify: {
    enabled: false
  }
};
