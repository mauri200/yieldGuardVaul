# YieldGuard-RHood

## Overview

YieldGuard-RHood is an MVP for Robinhood Chain that delivers a safer entry point into on-chain yield and risk-managed asset allocation. This project builds a multi-asset vault system where user deposits are routed automatically across reserve protection and yield strategies, helping retail investors preserve value while still accessing DeFi returns.

## Why this matters today

In the current crypto and DeFi landscape, retail users face:
- fragmented asset exposure across multiple protocols
- unclear risk controls for volatile markets
- limited access to simple, on-chain-backed savings solutions
- poor protection for stock-like assets and stablecoins during market storms

YieldGuard-RHood addresses these problems by giving users a single vault interface backed by smart contract logic, dynamic allocation, and protective reserve management.

## Problem solved for users

This MVP helps users by:
- enabling deposits in USDC and supported stock-like tokens on Robinhood Chain
- converting deposits into vault shares that represent pooled exposure
- allocating assets automatically into lending, stable yield, defensive, and collateral yield strategies
- preserving capital with a reserve vault when risk is high or storm mode is active
- simplifying withdrawals and multi-token redemption through a unified vault experience

## What this project includes

- `src/` — Solidity contracts for the vault, strategy router, reserve vault, allocation manager, risk engine, asset registry, and oracle
- `frontend/` — Next.js-based UI components and wallet integration for a minimal DeFi dashboard
- `scripts/` — deployment tools and ABI update helpers
- `test/` — JavaScript tests covering core vault behavior

## Core MVP features

- ERC4626-based vault with `YieldGuard Shares (YGS)`
- multi-token deposit support via `depositMulti`
- risk-aware allocation through `StormController` and `AllocationManager`
- strategy routing across lending, stable yield, defensive, and collateral yield strategies
- reserve capital protection using `ReserveVault`
- on-chain price oracle and supported asset registry
- secure contract ownership and role management for deployment

## How it works

1. A user deposits supported tokens into `YieldGuardVault`.
2. The vault mints shares in exchange for value locked in the system.
3. Deposited tokens are routed through `StrategyRouter`.
4. `AllocationManager` decides how much goes to yield strategies and how much stays in reserve.
5. `StormController` can shift allocations toward defensive positions when market risk is high.
6. Withdrawals are processed through the vault and router with asset-specific 

redemptions.
readmi/gmg.png
readmi/stormmode.png
readmi/yieldguard.png
## Getting started

Requirements:
- Node.js 20+
- npm
- Hardhat
- a Robinhood Chain RPC endpoint configured in `foundry.toml` or the Hardhat network settings

Install dependencies:

```bash
npm install
```

Compile contracts:

```bash
npm run compile
```

Run the local Hardhat node:

```bash
npm run node
```

Deploy to Robinhood Chain:

```bash
npm run deploy-foundry
```

## Project structure

- `src/` — core smart contract logic
- `frontend/` — user interface and dApp pages
- `scripts/` — deployment and ABI generation scripts
- `test/` — automated tests for vault behavior
- `foundry.toml`, `hardhat.config.js` — blockchain configuration

## Target audience

This repository is designed for:
- Robinhood Chain builders launching DeFi MVPs
- retail users seeking risk-managed yield exposure
- Solidity developers exploring multi-asset vault design
- teams validating on-chain allocation logic for new products

## Why Robinhood Chain

Robinhood Chain is well-suited for this MVP because it aims to support retail-friendly crypto assets and a fast on-chain experience. YieldGuard-RHood is built to demonstrate how a DeFi vault can work as a safe bridge between everyday users and more advanced yield strategies.

## License

This project is released under the ISC License.



ROBINHOOD_CHAIN_RPC=https://robinhood-testnet.g.alchemy.com/v2/57tU_3-qJy2TKKLuUdpbq
CHAIN_ID=46630
AMZN_TOKEN=0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02
TSLA_TOKEN=0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E
AMD_TOKEN=0x71178BAc73cBeb415514eB542a8995b82669778d
PLTR_TOKEN=0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0
NFLX_TOKEN=0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93
USDC_TOKEN=0x7E955252E15c84f5768B83c41a71F9eba181802F
VAULT=0xc6e3b276897eaf9562410d47fcd4a52b20192a4d
RISK_ENGINE=0x6545f8e6ecc1041a639c623ff3a01439659452c7
ALLOCATION_MANAGER=0x6a4b3a5b1e5c84f5768b83c41a71f9eba181802f
ROUTER=0xStrategyRouterAddress
STORM_CONTROLLER=0x887fc5e79d0f8dd031668e619b7cae68709bc96c
RESERVE_VAULT=0x364eda864a1e52033f57035a83b9157054d82fd8
ASSET_REGISTRY=0x1e605a59fb753ae0f0a836b59c25e3e95df91d0d
PRICE_ORACLE=0x9df3cf416f2f201aad81b350947f90befebf7ebe 