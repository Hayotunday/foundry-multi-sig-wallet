# Foundry Multi-Sig Wallet

A Foundry-based multisig smart wallet prototype that demonstrates how shared treasury control can be enforced through explicit confirmation workflows. This project models a governance-safe custody pattern where multiple signers must approve transactions before funds can move.

## What the product does
This project implements a multisig wallet where transactions are submitted, confirmed by multiple owners, and executed only after the required number of confirmations has been reached. The wallet tracks pending transactions, collects owner approvals, and prevents execution until the quorum threshold is met.

## The problem it solves
Single-owner wallets create custody risk. If one owner key is compromised, all funds can be stolen. A multisig wallet requires cooperation between multiple owners to move funds, which distributes risk and makes theft much harder.

## My specific contribution
I implemented the wallet's core logic, including transaction submission, confirmation tracking, revocation, and execution. The contract includes strict access control, clear error handling, and a well-defined transaction lifecycle.

## Architecture
The repository includes:

- `src/MultiSigWallet.sol` — core wallet logic
- `script/DeployMultiSigWallet.s.sol` — deployment script
- `test/MultiSigWalletTest.t.sol` — tests for confirmations and execution
- `lib/` — Foundry dependencies
- `foundry.toml` — Foundry configuration

## Technologies
- Solidity
- Foundry
- Forge testing
- Access control patterns
- Transaction lifecycle management

## Important technical decisions
- The wallet uses explicit owner validation to ensure only authorized addresses can confirm or execute transactions.
- Each transaction is stored in a struct containing proposer, recipient, value, calldata, execution state, and confirmation count.
- Quorum enforcement prevents execution until enough owners approve the transaction.
- Custom errors make invalid conditions clear and testable.
- The contract follows a checks-effects-interactions flow to reduce risk during execution.

## Key features
- Owner-based access control
- Transaction submission and tracking
- Multi-owner confirmation workflow
- Confirmation revocation
- Execution only after required signatures are collected
- Event-driven auditing of all wallet operations
- Protection against duplicate confirmations

## Screenshots
No screenshots are included.

## Live demo
No live deployment is included in the repository.

## Challenges and solutions
The biggest challenge is preventing double-confirmation and ensuring the confirmation process stays simple and safe. This is addressed by tracking per-owner confirmation state and validating it before each approval or execution step.

Another challenge is revocation safety. The solution is to decrement the confirmation count and maintain strict checks before an owner can change their vote.

## Setup instructions
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone
git clone https://github.com/Hayotunday/foundry-multi-sig-wallet.git
cd foundry-multi-sig-wallet

# Install dependencies
forge install

# Build
forge build

# Run tests
forge test

# Optional
forge fmt
forge snapshot
```
