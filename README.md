# OnlyTrust Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Solidity contracts for on-chain manifest anchoring and escrow settlement on Base. Foundry-tested, **not yet deployed**.

## Status

| Contract | Code | Tests | Deployed |
|----------|------|-------|----------|
| ManifestRegistry | Complete (43 lines) | 5 passing (Foundry) | Not yet |
| EscrowRouter | Security framework only (99 lines) | 7 passing (Foundry) | Not yet |

## ManifestRegistry — Complete

Agents publish SHA-256 hashes of their capability manifests on-chain, creating an immutable, verifiable record.

```solidity
publishManifest(bytes32 manifestHash)  // Anchor a manifest hash (one per hash, enforced)
revokeManifest(bytes32 manifestHash)   // Revoke (only the original publisher)
verifyManifest(bytes32 manifestHash)   // Returns (active, agent, timestamp)
```

- Ownable2Step access control (OpenZeppelin v5)
- Events: `ManifestAnchored`, `ManifestRevoked`
- Tested: publish, duplicate rejection, revocation, unauthorized revoke prevention, verify lookup
- **Ready for testnet deployment** — just needs a deployer key and RPC

## EscrowRouter — Security Framework Only

The EscrowRouter establishes the security architecture for USDC escrow but **does not yet implement core escrow logic**. All four main functions currently `revert("Not implemented")`:

- `deposit()` — `revert("Not implemented")`
- `claimSettlement()` — `revert("Not implemented")`
- `refund()` — `revert("Not implemented")`
- `splitSettlement()` — `revert("Not implemented")` (fee cap validated: max 10% BPS)

### What IS implemented

- **ReentrancyGuard** on all external functions
- **Pausable** with owner-only pause/unpause
- **EIP-712** domain separator (`"OnlyTrustEscrow", "1"`)
- **Ownable2Step** for ownership transfers
- **24-hour timelock signer rotation** — fully implemented and tested:
  - `initiateSignerRotation(address)` → sets `pendingSigner` + 24h delay
  - `cancelSignerRotation()` → clears pending rotation
  - `finalizeSignerRotation()` → activates new signer after timelock expires

Tests verify: deployment, all 4 core functions correctly revert, signer rotation initiate/cancel/finalize, timelock enforcement.

### What's next

Implementing `deposit`, `claimSettlement`, `refund`, and `splitSettlement` with actual USDC (ERC-20) transfers and EIP-712 signature verification. The security rails are in place — the business logic is next.

## Tech Stack

- **Solidity** 0.8.28 (via-ir optimization)
- **Foundry** for testing (primary)
- **Hardhat** for compilation and deployment scripts
- **OpenZeppelin** Contracts v5 (Ownable2Step, ReentrancyGuard, Pausable, EIP712)
- **Chain target:** Base (Sepolia testnet / mainnet)

## Setup

```bash
npm install

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Testing

```bash
# Foundry (recommended)
forge test

# Hardhat
npx hardhat test
```

## Deployment

ManifestRegistry is ready for testnet deployment. EscrowRouter deployment is blocked on implementing core escrow logic.

```bash
cp .env.example .env
# Edit .env with deployer key and RPC URLs

# Deploy to Base Sepolia (when ready)
npm run deploy:sepolia
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

## Audit Status

Contracts are **unaudited**. Use at your own risk.

## Related Repos

| Repo | What |
|------|------|
| [onlytrust-a2a](https://github.com/onlytrust-ai/onlytrust-a2a) | Rails API — agents, tasks, manifests |
| [onlytrust-core](https://github.com/onlytrust-ai/onlytrust-core) | Shared Ruby gem — models, encryption, auth |
| [onlytrust-dashboard](https://github.com/onlytrust-ai/onlytrust-dashboard) | Next.js dashboard — agent management UI |

## License

[MIT](LICENSE) — Copyright 2026 OnlyTrust.
