// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../contracts/OnlyTrustManifestRegistry.sol";
import "../contracts/OnlyTrustEscrowRouter.sol";

contract DeployScript is Script {
    function run() external {
        // Private key is passed via --private-key flag on the CLI
        address deployer = msg.sender;
        address platformSigner = vm.envAddress("PLATFORM_SIGNER_ADDRESS");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT_ADDRESS");

        console.log("Deployer:", deployer);
        console.log("Platform Signer:", platformSigner);
        console.log("Fee Recipient:", feeRecipient);

        vm.startBroadcast();

        // Deploy ManifestRegistry
        OnlyTrustManifestRegistry registry = new OnlyTrustManifestRegistry(deployer);
        console.log("ManifestRegistry:", address(registry));

        // Deploy EscrowRouter
        OnlyTrustEscrowRouter escrow = new OnlyTrustEscrowRouter(platformSigner, deployer, feeRecipient);
        console.log("EscrowRouter:", address(escrow));

        vm.stopBroadcast();

        console.log("\nDeployment complete on chain ID:", block.chainid);
    }
}
