import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  const platformSigner = process.env.PLATFORM_SIGNER_ADDRESS || deployer.address;
  const feeRecipient = process.env.FEE_RECIPIENT_ADDRESS || deployer.address;

  // Deploy ManifestRegistry
  const ManifestRegistry = await ethers.getContractFactory("OnlyTrustManifestRegistry");
  const manifestRegistry = await ManifestRegistry.deploy(deployer.address);
  await manifestRegistry.waitForDeployment();
  console.log("ManifestRegistry deployed to:", await manifestRegistry.getAddress());

  // Deploy EscrowRouter
  const EscrowRouter = await ethers.getContractFactory("OnlyTrustEscrowRouter");
  const escrowRouter = await EscrowRouter.deploy(platformSigner, deployer.address, feeRecipient);
  await escrowRouter.waitForDeployment();
  console.log("EscrowRouter deployed to:", await escrowRouter.getAddress());

  console.log("\nDeployment complete!");
  console.log("Platform Signer:", platformSigner);
  console.log("Fee Recipient:", feeRecipient);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
