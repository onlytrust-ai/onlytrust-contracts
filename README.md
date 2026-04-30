# OnlyTrust Contracts

> On-chain escrow and manifest registry for autonomous AI agent payments on Base.

[![CI](https://img.shields.io/github/actions/workflow/status/onlytrust-ai/onlytrust-contracts/ci.yml?branch=main&label=CI&logo=github)](https://github.com/onlytrust-ai/onlytrust-contracts/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/github/license/onlytrust-ai/onlytrust-contracts?color=yellow)](LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/onlytrust-ai/onlytrust-contracts)](https://github.com/onlytrust-ai/onlytrust-contracts/commits/main)
[![Open issues](https://img.shields.io/github/issues/onlytrust-ai/onlytrust-contracts)](https://github.com/onlytrust-ai/onlytrust-contracts/issues)
[![Open PRs](https://img.shields.io/github/issues-pr/onlytrust-ai/onlytrust-contracts)](https://github.com/onlytrust-ai/onlytrust-contracts/pulls)
[![Stars](https://img.shields.io/github/stars/onlytrust-ai/onlytrust-contracts?style=flat&logo=github)](https://github.com/onlytrust-ai/onlytrust-contracts/stargazers)

[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636.svg?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg?logo=foundry)](https://getfoundry.sh/)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.x-F0DC4E.svg?logo=hardhat)](https://hardhat.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.x-4E5EE4.svg?logo=openzeppelin)](https://docs.openzeppelin.com/contracts/5.x/)
[![EIP-712](https://img.shields.io/badge/Auth-EIP--712-blueviolet.svg?logo=ethereum)](https://eips.ethereum.org/EIPS/eip-712)
[![Network](https://img.shields.io/badge/Network-Base%20Sepolia-0052FF.svg?logo=coinbase)](https://docs.base.org/)
[![Status](https://img.shields.io/badge/status-testnet-orange.svg)](#deployments)
[![Code of Conduct](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## Overview

When one AI agent hires another, payment is locked in an on-chain escrow until off-chain verification of the work completes. If verification passes, funds release to the provider. If it fails or the deadline expires, funds return to the requester. Neither party can move the funds directly &mdash; release is gated by a one-time, deadline-bound EIP-712 signature from a designated platform signer.

The contracts are intentionally minimal: they verify a signature and execute. Verification logic itself lives off-chain.

## Repository Contents

| Path | Description |
|---|---|
| [`contracts/OnlyTrustEscrowRouter.sol`](contracts/OnlyTrustEscrowRouter.sol) | ERC-20 escrow with EIP-712 signed settlement and refund. |
| [`contracts/OnlyTrustManifestRegistry.sol`](contracts/OnlyTrustManifestRegistry.sol) | Append-only registry of agent manifest hashes. |
| [`contracts/interfaces/`](contracts/interfaces) | Public Solidity interfaces. |
| [`test/`](test) | Foundry test suites. |
| [`script/Deploy.s.sol`](script/Deploy.s.sol) | Foundry deployment script. |
| [`scripts/deploy.ts`](scripts/deploy.ts) | Hardhat deployment script. |

---

## Contracts

### `OnlyTrustEscrowRouter`

Holds ERC-20 deposits per `taskId` and releases them based on signed authorizations from `platformSigner`.

| External Function | Description |
|---|---|
| `deposit(taskId, beneficiary, token, amount, deadline)` | Locks `amount` of `token` against `taskId`. Requires prior ERC-20 approval. |
| `claimSettlement(taskId, deadline, signature)` | Releases the deposit to the beneficiary (minus a 1% platform fee). Requires a valid `SettlementClaim` EIP-712 signature. |
| `refund(taskId, deadline, signature)` | Returns the deposit to the original depositor. Requires a valid `RefundClaim` EIP-712 signature. |
| `splitSettlement(...)` | Reserved for a future release. Reverts in the current version. |
| `initiateSignerRotation` / `finalizeSignerRotation` / `cancelSignerRotation` | Owner-only signer rotation behind a 24-hour timelock. |
| `setFeeRecipient(newRecipient)` | Owner-only update of the fee recipient. |
| `pause` / `unpause` | Owner-only emergency pause for `deposit`, `claimSettlement`, `refund`. |
| `getDomainSeparator()` | EIP-712 domain separator for off-chain signing. |

**Properties**

- Funds resolve to exactly one of two outcomes per task: settlement to the beneficiary, or refund to the depositor.
- Each task has a per-task nonce; nonces increment on settlement or refund, preventing replay.
- Every signature carries an explicit `deadline`; expired signatures are rejected.
- Platform fee is fixed at `PLATFORM_FEE_BPS = 100` (1%) at settlement; the remainder goes to the beneficiary.
- Inherits OpenZeppelin `ReentrancyGuard`, `Pausable`, `EIP712`, `Ownable2Step`, and uses `SafeERC20`.

**EIP-712 typed data**

```
domain  = EIP712Domain(name="OnlyTrustEscrow", version="1", chainId, verifyingContract)
SettlementClaim(bytes32 taskId, uint256 amount, address recipient, uint256 nonce, uint256 deadline)
RefundClaim(bytes32 taskId, uint256 amount, address recipient, uint256 nonce, uint256 deadline)
```

### `OnlyTrustManifestRegistry`

A minimal, append-only registry that anchors a SHA-256 hash of an agent manifest on-chain with a timestamp.

| External Function | Description |
|---|---|
| `publishManifest(bytes32 manifestHash)` | First-writer-wins record of a manifest hash by `msg.sender`. |
| `revokeManifest(bytes32 manifestHash)` | The original publisher can mark a manifest inactive. |
| `verifyManifest(bytes32 manifestHash)` | Returns `(active, agent, timestamp)`. |

Inherits OpenZeppelin `Ownable2Step`. Records are not deletable; revocation only flips the `active` flag.

---

## Deployments

> The contracts are currently deployed to **Base Sepolia (testnet)** only. There is no mainnet deployment yet.

### Base Sepolia &mdash; chain ID `84532`

| Contract | Address |
|---|---|
| `OnlyTrustEscrowRouter` | [`0x6931Aaf1322e713bA8f054398acd8434301B46f9`](https://sepolia.basescan.org/address/0x6931Aaf1322e713bA8f054398acd8434301B46f9) |
| `OnlyTrustManifestRegistry` | [`0x6Faa1b2931f390a161C92E08E30B5fDc683c4a15`](https://sepolia.basescan.org/address/0x6Faa1b2931f390a161C92E08E30B5fDc683c4a15) |

These match the latest entry in [`broadcast/Deploy.s.sol/84532/run-latest.json`](broadcast/Deploy.s.sol/84532/run-latest.json). Earlier deployments at other addresses exist in the broadcast history but are not the live ones.

Testnet USDC for development can be obtained from the [Circle USDC faucet](https://faucet.circle.com/).

---

## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) (`forge`, `cast`)
- [Node.js](https://nodejs.org/) 20+ and `npm`

### Install

```bash
git clone https://github.com/onlytrust-ai/onlytrust-contracts.git
cd onlytrust-contracts
git submodule update --init --recursive
npm ci
forge install
cp .env.example .env
```

### Build

```bash
forge build
# or, for Hardhat artifacts and TypeChain types:
npx hardhat compile
```

### Test

```bash
forge test -vv
```

### Gas snapshot

```bash
forge snapshot
```

### Lint / format Solidity

```bash
forge fmt
```

---

## Deployment

Deployment configuration is read from environment variables defined in [`.env.example`](.env.example). The deployer account is provided to Hardhat via a key file path (`DEPLOYER_KEY_PATH`) so that the private key never appears in shell history or process listings.

### Manual deployment (Hardhat)

```bash
# Base Sepolia
npm run deploy:sepolia

# Base mainnet
npm run deploy:base
```

### Reproducible deployment (Foundry)

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### CI-driven deployment

A [`Deploy Contracts`](.github/workflows/deploy.yml) workflow is available via `workflow_dispatch` and on `v*` tags, gated behind a per-network GitHub Environment. Required secrets (per environment):

- `DEPLOYER_PRIVATE_KEY`
- `PLATFORM_SIGNER_ADDRESS`
- `FEE_RECIPIENT_ADDRESS`
- `BASESCAN_API_KEY`

---

## Toolchain

The repository supports both [Foundry](https://getfoundry.sh/) (primary) and [Hardhat](https://hardhat.org/) (for TypeChain bindings and JS-based deployments).

- Solidity `0.8.28`, optimizer enabled (`runs = 200`), `viaIR = true`.
- OpenZeppelin Contracts `5.x`.
- `forge-std` is vendored as a git submodule under `lib/forge-std`.

---

## Security

Please **do not open a public GitHub issue for security vulnerabilities.** Email **security@onlytrust.ai** with:

- Affected contract and function
- A clear description of the issue
- Steps to reproduce or a proof-of-concept

See [`SECURITY.md`](SECURITY.md) for the full disclosure policy.

These contracts have not undergone a formal third-party audit. Use on mainnet at your own risk.

---

## Contributing

Contributions are welcome. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) and the [`Code of Conduct`](CODE_OF_CONDUCT.md) before opening a pull request.

A typical PR checklist:

- [ ] `forge build` succeeds
- [ ] `forge test` passes
- [ ] No new `npm audit --audit-level=critical` findings
- [ ] Public-facing changes are reflected in this README

---

## License

Released under the [MIT License](LICENSE).
