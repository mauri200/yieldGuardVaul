const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // 1. Deploy Mock Tokens
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const usdc = await MockERC20.deploy("Mock USDC", "USDC", 6);
  await usdc.waitForDeployment();
  const amzn = await MockERC20.deploy("Mock Amazon", "AMZN", 18);
  await amzn.waitForDeployment();
  const tsla = await MockERC20.deploy("Mock Tesla", "TSLA", 18);
  await tsla.waitForDeployment();
  const spy = await MockERC20.deploy("Mock SPY ETF", "SPY", 18);
  await spy.waitForDeployment();

  const usdcAddr = await usdc.getAddress();
  const amznAddr = await amzn.getAddress();
  const tslaAddr = await tsla.getAddress();
  const spyAddr = await spy.getAddress();

  console.log("Mock USDC deployed to:", usdcAddr);
  console.log("Mock AMZN deployed to:", amznAddr);
  console.log("Mock TSLA deployed to:", tslaAddr);
  console.log("Mock SPY deployed to:", spyAddr);

  // 2. Deploy Mock Lending Market
  const MockLendingMarket = await ethers.getContractFactory("MockLendingMarket");
  const lendingMarket = await MockLendingMarket.deploy();
  await lendingMarket.waitForDeployment();
  const lendingMarketAddr = await lendingMarket.getAddress();
  console.log("MockLendingMarket deployed to:", lendingMarketAddr);

  // 3. Deploy Price Oracle
  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const oracle = await PriceOracle.deploy();
  await oracle.waitForDeployment();
  const oracleAddr = await oracle.getAddress();
  console.log("PriceOracle deployed to:", oracleAddr);

  // Set default prices (scaled to 18 decimals)
  const usdcPrice = ethers.parseEther("1.00");
  const amznPrice = ethers.parseEther("180.00");
  const tslaPrice = ethers.parseEther("170.00");
  const spyPrice = ethers.parseEther("500.00");

  await oracle.setPrice(usdcAddr, usdcPrice);
  await oracle.setPrice(amznAddr, amznPrice);
  await oracle.setPrice(tslaAddr, tslaPrice);
  await oracle.setPrice(spyAddr, spyPrice);
  console.log("Initial oracle prices set.");

  // 4. Deploy Risk Engine
  const RiskEngine = await ethers.getContractFactory("RiskEngine");
  const riskEngine = await RiskEngine.deploy();
  await riskEngine.waitForDeployment();
  const riskEngineAddr = await riskEngine.getAddress();
  console.log("RiskEngine deployed to:", riskEngineAddr);

  // 5. Deploy Allocation Manager
  const AllocationManager = await ethers.getContractFactory("AllocationManager");
  const allocationManager = await AllocationManager.deploy();
  await allocationManager.waitForDeployment();
  const allocationManagerAddr = await allocationManager.getAddress();
  console.log("AllocationManager deployed to:", allocationManagerAddr);

  // 6. Deploy Storm Controller
  const StormController = await ethers.getContractFactory("StormController");
  const stormController = await StormController.deploy(riskEngineAddr);
  await stormController.waitForDeployment();
  const stormControllerAddr = await stormController.getAddress();
  console.log("StormController deployed to:", stormControllerAddr);

  // 7. Deploy Reserve Vault
  const ReserveVault = await ethers.getContractFactory("ReserveVault");
  const reserveVault = await ReserveVault.deploy([usdcAddr, amznAddr, tslaAddr, spyAddr]);
  await reserveVault.waitForDeployment();
  const reserveVaultAddr = await reserveVault.getAddress();
  console.log("ReserveVault deployed to:", reserveVaultAddr);

  // 8. Deploy Strategy Router
  const StrategyRouter = await ethers.getContractFactory("StrategyRouter");
  const strategyRouter = await StrategyRouter.deploy(
    allocationManagerAddr,
    stormControllerAddr,
    reserveVaultAddr,
    oracleAddr,
    usdcAddr,
    [amznAddr, tslaAddr, spyAddr]
  );
  await strategyRouter.waitForDeployment();
  const routerAddr = await strategyRouter.getAddress();
  console.log("StrategyRouter deployed to:", routerAddr);

  // 9. Deploy YieldGuardVault (ERC-4626)
  const YieldGuardVault = await ethers.getContractFactory("YieldGuardVault");
  const vault = await YieldGuardVault.deploy(
    usdcAddr,
    oracleAddr,
    reserveVaultAddr,
    routerAddr
  );
  await vault.waitForDeployment();
  const vaultAddr = await vault.getAddress();
  console.log("YieldGuardVault deployed to:", vaultAddr);

  // 10. Deploy Strategies (using the real vaultAddr!)
  const LendingStrategy = await ethers.getContractFactory("LendingStrategy");
  const lendingStrategy = await LendingStrategy.deploy(
    routerAddr,
    vaultAddr,
    oracleAddr,
    lendingMarketAddr,
    [usdcAddr]
  );
  await lendingStrategy.waitForDeployment();
  const lendingStrategyAddr = await lendingStrategy.getAddress();

  const StableYieldStrategy = await ethers.getContractFactory("StableYieldStrategy");
  const stableYieldStrategy = await StableYieldStrategy.deploy(
    routerAddr,
    vaultAddr,
    oracleAddr,
    lendingMarketAddr,
    usdcAddr
  );
  await stableYieldStrategy.waitForDeployment();
  const stableYieldStrategyAddr = await stableYieldStrategy.getAddress();

  const CollateralYieldStrategy = await ethers.getContractFactory("CollateralYieldStrategy");
  const collateralYieldStrategy = await CollateralYieldStrategy.deploy(
    routerAddr,
    vaultAddr,
    oracleAddr,
    usdcAddr,
    [amznAddr, tslaAddr, spyAddr]
  );
  await collateralYieldStrategy.waitForDeployment();
  const collateralYieldStrategyAddr = await collateralYieldStrategy.getAddress();

  const DefensiveStrategy = await ethers.getContractFactory("DefensiveStrategy");
  const defensiveStrategy = await DefensiveStrategy.deploy(
    routerAddr,
    vaultAddr,
    oracleAddr,
    usdcAddr
  );
  await defensiveStrategy.waitForDeployment();
  const defensiveStrategyAddr = await defensiveStrategy.getAddress();

  console.log("Strategies deployed with correct vault association.");

  // 11. Configure StrategyRouter
  await strategyRouter.setVault(vaultAddr);
  await strategyRouter.setStrategies(
    lendingStrategyAddr,
    collateralYieldStrategyAddr,
    stableYieldStrategyAddr,
    defensiveStrategyAddr
  );
  console.log("StrategyRouter configured with strategies.");

  // 12. Configure CollateralYieldStrategy
  await collateralYieldStrategy.setStableYieldStrategy(stableYieldStrategyAddr);

  // 13. Configure StormController
  await stormController.setStrategyRouter(routerAddr);
  await stormController.setReserveVault(reserveVaultAddr);

  // 14. Configure ReserveVault
  await reserveVault.setVaultAndRouter(vaultAddr, routerAddr);
  console.log("Protocol configurations completed.");

  // Mint some mock tokens to deployer for testing
  await usdc.mint(deployer.address, ethers.parseUnits("100000", 6));
  await amzn.mint(deployer.address, ethers.parseEther("1000"));
  await tsla.mint(deployer.address, ethers.parseEther("1000"));
  await spy.mint(deployer.address, ethers.parseEther("1000"));
  console.log("Mock tokens minted for test account.");

  // Save artifacts for frontend
  saveFrontendFiles({
    USDC: usdcAddr,
    AMZN: amznAddr,
    TSLA: tslaAddr,
    SPY: spyAddr,
    MockLendingMarket: lendingMarketAddr,
    PriceOracle: oracleAddr,
    RiskEngine: riskEngineAddr,
    AllocationManager: allocationManagerAddr,
    StormController: stormControllerAddr,
    ReserveVault: reserveVaultAddr,
    StrategyRouter: routerAddr,
    LendingStrategy: lendingStrategyAddr,
    StableYieldStrategy: stableYieldStrategyAddr,
    CollateralYieldStrategy: collateralYieldStrategyAddr,
    DefensiveStrategy: defensiveStrategyAddr,
    YieldGuardVault: vaultAddr,
  });
}

function saveFrontendFiles(addresses) {
  const contractsDir = path.join(__dirname, "..", "frontend", "src", "contracts");

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir, { recursive: true });
  }

  // Save addresses
  fs.writeFileSync(
    path.join(contractsDir, "addresses.json"),
    JSON.stringify(addresses, undefined, 2)
  );
  console.log("Saved deployed addresses to frontend.");

  // Save ABIs
  const abis = {};
  const contractNames = [
    "MockERC20",
    "MockLendingMarket",
    "PriceOracle",
    "RiskEngine",
    "AllocationManager",
    "StormController",
    "ReserveVault",
    "StrategyRouter",
    "LendingStrategy",
    "StableYieldStrategy",
    "CollateralYieldStrategy",
    "DefensiveStrategy",
    "YieldGuardVault"
  ];

  for (const name of contractNames) {
    const artifactPath = path.join(
      __dirname,
      "..",
      "artifacts",
      "contracts",
      name === "MockERC20" || name === "MockLendingMarket" ? `mocks/${name}.sol` :
      name.endsWith("Strategy") ? `strategies/${name}.sol` : `${name}.sol`,
      `${name}.json`
    );
    if (fs.existsSync(artifactPath)) {
      const artifact = JSON.parse(fs.readFileSync(artifactPath));
      abis[name] = artifact.abi;
    }
  }

  fs.writeFileSync(
    path.join(contractsDir, "abis.json"),
    JSON.stringify(abis, undefined, 2)
  );
  console.log("Saved ABIs to frontend.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
