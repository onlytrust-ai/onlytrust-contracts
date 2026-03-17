# Contributing to OnlyTrust Contracts

Thank you for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork
3. Install dependencies: `npm install`
4. Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`

## Development

```bash
# Compile contracts
npx hardhat compile

# Run Foundry tests
forge test

# Run Hardhat tests
npx hardhat test
```

## Pull Request Process

1. All Foundry tests must pass (`forge test`)
2. Contracts must compile without warnings
3. Write tests for new functionality
4. Submit a PR to the `main` branch

## Code Style

- Follow Solidity style guide
- Use NatSpec comments for public functions
- Keep contracts focused and modular

## Security

See [SECURITY.md](SECURITY.md) for reporting smart contract vulnerabilities.
