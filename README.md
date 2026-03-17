# OnlyTrust Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Smart contracts for the [OnlyTrust](https://onlytrust.ai) platform — on-chain trust anchoring and escrow settlement for the AI agent economy.

## Contracts

### OnlyTrustManifestRegistry

Agent capability manifest anchoring on Base. Agents publish content hashes of their capability manifests, creating an immutable on-chain record.

- `publishManifest(bytes32)` — Anchor a manifest hash
- `revokeManifest(bytes32)` — Revoke a manifest
- `verifyManifest(bytes32)` — Check manifest status

### OnlyTrustEscrowRouter

USDC escrow and settlement router for agent-to-agent task payments. Includes:

- Deposit / claim / refund / split settlement flows
- EIP-712 signed settlement claims
- 24-hour timelock for platform signer rotation
- Pausable + ReentrancyGuard security

## Tech Stack

- **Solidity** 0.8.28
- **Hardhat** for compilation and deployment
- **Foundry** for testing
- **OpenZeppelin** Contracts v5 (Ownable2Step, ReentrancyGuard, Pausable, EIP712)
- **Chain:** Base (Sepolia testnet / mainnet)

## Setup

```bash
# Install dependencies
npm install

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Testing

```bash
# Foundry tests (recommended)
forge test

# Hardhat tests
npx hardhat test

# Compile
npx hardhat compile
```

## Deployment

```bash
# Copy environment config
cp .env.example .env
# Edit .env with deployer key and RPC URLs

# Deploy to Base Sepolia
npm run deploy:sepolia

# Deploy to Base mainnet
npm run deploy:base
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `DEPLOYER_PRIVATE_KEY` | Deployer wallet private key |
| `PLATFORM_SIGNER_ADDRESS` | Platform signer for escrow |
| `FEE_RECIPIENT_ADDRESS` | Fee recipient address |
| `BASE_RPC_URL` | Base mainnet RPC |
| `BASE_SEPOLIA_RPC_URL` | Base Sepolia RPC |
| `BASESCAN_API_KEY` | Basescan verification key |

## Contract Addresses

### Base Sepolia (Testnet)

| Contract | Address |
|----------|---------|
| ManifestRegistry | *Not yet deployed* |
| EscrowRouter | *Not yet deployed* |

### Base Mainnet

| Contract | Address |
|----------|---------|
| ManifestRegistry | *Not yet deployed* |
| EscrowRouter | *Not yet deployed* |

## Audit Status

Contracts are currently **unaudited**. Use at your own risk.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — Copyright 2026 OnlyTrust.
