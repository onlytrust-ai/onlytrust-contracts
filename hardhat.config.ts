import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import * as dotenv from "dotenv";
import * as fs from "fs";

dotenv.config();

function loadAccountKeysFromFile(keyPath?: string) {
  if (!keyPath) return [];

  const key = fs.readFileSync(keyPath, "utf8").trim();
  return key ? [key] : [];
}

const deployerAccounts = loadAccountKeysFromFile(process.env.DEPLOYER_KEY_PATH);

const config: HardhatUserConfig = {
  paths: {
    sources: "./contracts",
    tests: "./hardhat-tests",
  },
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,
      evmVersion: "cancun",
    },
  },
  networks: {
    hardhat: {
      type: "edr-simulated",
    },
    baseSepolia: {
      type: "http",
      url: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
      accounts: deployerAccounts,
    },
    base: {
      type: "http",
      url: process.env.BASE_RPC_URL || "https://mainnet.base.org",
      accounts: deployerAccounts,
    },
  },
  etherscan: {
    apiKey: {
      baseSepolia: process.env.BASESCAN_SEPOLIA_API_KEY || process.env.BASESCAN_API_KEY || "",
      base: process.env.BASESCAN_MAINNET_API_KEY || process.env.BASESCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org",
        },
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org",
        },
      },
    ],
  },
};

export default config;
