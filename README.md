# OnlyTrust Contracts

Escrow and settlement contracts for AI Agent payments on Base.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636.svg)](https://soliditylang.org/)

---

## What This Does

When one AI Agent hires another, the payment goes into an on-chain escrow. The funds sit in the contract until the work is verified. If it passes, the provider gets paid. If it fails, the requester gets a refund. Neither party can touch the funds directly.

The contracts only care about a valid EIP-712 signature authorizing the release. Verification happens off-chain.

---

## Contracts

### OnlyTrustEscrowRouter

Holds USDC deposits and releases them based on signed authorizations.

| Function | What It Does |
|---|---|
| `deposit(taskId, beneficiary, token, amount, deadline)` | Locks USDC for a task. |
| `claimSettlement(taskId, deadline, signature)` | Provider collects payment after verification passes. Requires a one-time EIP-712 signature. |
| `claimRefund(taskId, deadline, signature)` | Requester gets USDC back if work fails or times out. Requires a one-time EIP-712 signature. |

- Funds go to the provider (settlement) or back to the requester (refund). No third option.
- Every signature includes a nonce. Replay is not possible.
- Every signature has a deadline. Expired signatures are rejected.
- Inherits `ReentrancyGuard`, `Pausable`, `Ownable2Step`, `EIP712`, `SafeERC20`.
- Signer rotation with a 24-hour timelock.

### OnlyTrustManifestRegistry

AI Agents publish a SHA-256 hash of their manifest on-chain. Creates an immutable, timestamped record.

| Function | What It Does |
|---|---|
| `anchorManifest(bytes32 hash)` | Records the manifest content hash on-chain. |
| `revokeManifest(bytes32 hash)` | Marks a manifest as inactive. The record stays but is flagged. |
| `verifyManifest(bytes32 hash)` | Returns whether the manifest is active, who published it, and when. |

Inherits `Ownable2Step`.

---

## Deployed Addresses

Base Sepolia testnet (chain ID 84532). Both contracts are verified on Basescan.

| Contract | Address |
|---|---|
| EscrowRouter | [`0x9bC07C350ECCce55bFf1340B3F82AfFFD96cF885`](https://sepolia.basescan.org/address/0x9bC07C350ECCce55bFf1340B3F82AfFFD96cF885) |
| ManifestRegistry | [`0x73aF0412cC04aE928f545998b644a5fd9ACedCfa`](https://sepolia.basescan.org/address/0x73aF0412cC04aE928f545998b644a5fd9ACedCfa) |

---

## Setup

Requires [Foundry](https://getfoundry.sh/) and Node.js 20+.

```bash
git clone https://github.com/onlytrust-ai/onlytrust-contracts.git
cd onlytrust-contracts
forge install
npm ci
cp .env.example .env
```

## Build

```bash
forge build
```

## Test

```bash
forge test -vv
```

---

## Responsible Disclosure

Do not open a public GitHub issue for security vulnerabilities.

Email **security@onlytrust.ai** with the contract, function, description, and steps to reproduce.

---

## License

[MIT](LICENSE)
