const fs = require('fs');
const path = require('path');

const addressesPath = path.join(__dirname, '..', 'frontend', 'src', 'contracts', 'addresses.json');
const abisPath = path.join(__dirname, '..', 'frontend', 'src', 'contracts', 'abis.json');
const outDir = path.join(__dirname, '..', 'out');

// Mapping from addresses.json key to the Foundry output file path
const keyToArtifact = {
  USDC: 'MockERC20.sol/MockERC20.json',
  AMZN: 'MockERC20.sol/MockERC20.json',
  TSLA: 'MockERC20.sol/MockERC20.json',
  PLTR: 'MockERC20.sol/MockERC20.json',
  NFLX: 'MockERC20.sol/MockERC20.json',
  AMD: 'MockERC20.sol/MockERC20.json',
  MockLendingMarket: 'MockLendingMarket.sol/MockLendingMarket.json',
  PriceOracle: 'PriceOracle.sol/PriceOracle.json',
  RiskEngine: 'RiskEngine.sol/RiskEngine.json',
  AllocationManager: 'AllocationManager.sol/AllocationManager.json',
  StormController: 'StormController.sol/StormController.json',
  ReserveVault: 'ReserveVault.sol/ReserveVault.json',
  StrategyRouter: 'StrategyRouter.sol/StrategyRouter.json',
  LendingStrategy: 'LendingStrategy.sol/LendingStrategy.json',
  StableYieldStrategy: 'StableYieldStrategy.sol/StableYieldStrategy.json',
  CollateralYieldStrategy: 'CollateralYieldStrategy.sol/CollateralYieldStrategy.json',
  DefensiveStrategy: 'DefensiveStrategy.sol/DefensiveStrategy.json',
  AssetRegistry: 'AssetRegistry.sol/AssetRegistry.json',
  YieldGuardVault: 'YieldGuardVault.sol/YieldGuardVault.json'
};

function main() {
  if (!fs.existsSync(addressesPath)) {
    console.error('addresses.json not found. Run deployment first.');
    process.exit(1);
  }

  const addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
  const abis = {};

  for (const key of Object.keys(addresses)) {
    const artifactRelPath = keyToArtifact[key];
    if (!artifactRelPath) {
      console.warn(`No mapping found for key: ${key}`);
      continue;
    }

    const artifactPath = path.join(outDir, artifactRelPath);
    if (!fs.existsSync(artifactPath)) {
      console.error(`Artifact not found at ${artifactPath}. Did you build the project?`);
      process.exit(1);
    }

    try {
      const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
      if (artifact && artifact.abi) {
        abis[key] = artifact.abi;
        console.log(`Extracted ABI for ${key}`);
      } else {
        console.error(`No ABI found in artifact for ${key}`);
      }
    } catch (err) {
      console.error(`Error reading artifact for ${key}:`, err);
    }
  }

  fs.writeFileSync(abisPath, JSON.stringify(abis, null, 2), 'utf8');
  console.log(`Saved compiled ABIs to ${abisPath}`);
}

main();
