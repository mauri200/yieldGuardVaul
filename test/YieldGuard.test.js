const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("YieldGuard System", function () {
  let deployer, user;
  let usdc, amzn, tsla, spy;
  let lendingMarket, oracle, riskEngine, allocationManager, stormController, reserveVault, strategyRouter;
  let vault;
  let lendingStrategy, stableYieldStrategy, collateralYieldStrategy, defensiveStrategy;

  beforeEach(async function () {
    [deployer, user] = await ethers.getSigners();

    // Deploy Mock tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    usdc = await MockERC20.deploy("Mock USDC", "USDC", 6);
    amzn = await MockERC20.deploy("Mock Amazon", "AMZN", 18);
    tsla = await MockERC20.deploy("Mock Tesla", "TSLA", 18);
    spy = await MockERC20.deploy("Mock SPY ETF", "SPY", 18);

    const usdcAddr = await usdc.getAddress();
    const amznAddr = await amzn.getAddress();
    const tslaAddr = await tsla.getAddress();
    const spyAddr = await spy.getAddress();

    // Deploy Mock Lending Market
    const MockLendingMarket = await ethers.getContractFactory("MockLendingMarket");
    lendingMarket = await MockLendingMarket.deploy();
    const lendingMarketAddr = await lendingMarket.getAddress();

    // Deploy Price Oracle
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    oracle = await PriceOracle.deploy();
    const oracleAddr = await oracle.getAddress();

    // Set prices: USDC = $1, AMZN = $200, TSLA = $100, SPY = $500
    await oracle.setPrice(usdcAddr, ethers.parseEther("1.00"));
    await oracle.setPrice(amznAddr, ethers.parseEther("200.00"));
    await oracle.setPrice(tslaAddr, ethers.parseEther("100.00"));
    await oracle.setPrice(spyAddr, ethers.parseEther("500.00"));

    // Deploy Risk Engine
    const RiskEngine = await ethers.getContractFactory("RiskEngine");
    riskEngine = await RiskEngine.deploy();
    const riskEngineAddr = await riskEngine.getAddress();

    // Deploy Allocation Manager
    const AllocationManager = await ethers.getContractFactory("AllocationManager");
    allocationManager = await AllocationManager.deploy();
    const allocationManagerAddr = await allocationManager.getAddress();

    // Deploy Storm Controller
    const StormController = await ethers.getContractFactory("StormController");
    stormController = await StormController.deploy(riskEngineAddr);
    const stormControllerAddr = await stormController.getAddress();

    // Deploy Reserve Vault
    const ReserveVault = await ethers.getContractFactory("ReserveVault");
    reserveVault = await ReserveVault.deploy([usdcAddr, amznAddr, tslaAddr, spyAddr]);
    const reserveVaultAddr = await reserveVault.getAddress();

    // Deploy Strategy Router
    const StrategyRouter = await ethers.getContractFactory("StrategyRouter");
    strategyRouter = await StrategyRouter.deploy(
      allocationManagerAddr,
      stormControllerAddr,
      reserveVaultAddr,
      oracleAddr,
      usdcAddr,
      [amznAddr, tslaAddr, spyAddr]
    );
    const routerAddr = await strategyRouter.getAddress();

    // Deploy YieldGuardVault
    const YieldGuardVault = await ethers.getContractFactory("YieldGuardVault");
    vault = await YieldGuardVault.deploy(usdcAddr, oracleAddr, reserveVaultAddr, routerAddr);
    const vaultAddr = await vault.getAddress();

    // Deploy Strategies
    const LendingStrategy = await ethers.getContractFactory("LendingStrategy");
    lendingStrategy = await LendingStrategy.deploy(routerAddr, vaultAddr, oracleAddr, lendingMarketAddr, [usdcAddr]);
    const lendingStrategyAddr = await lendingStrategy.getAddress();

    const StableYieldStrategy = await ethers.getContractFactory("StableYieldStrategy");
    stableYieldStrategy = await StableYieldStrategy.deploy(routerAddr, vaultAddr, oracleAddr, lendingMarketAddr, usdcAddr);
    const stableYieldStrategyAddr = await stableYieldStrategy.getAddress();

    const CollateralYieldStrategy = await ethers.getContractFactory("CollateralYieldStrategy");
    collateralYieldStrategy = await CollateralYieldStrategy.deploy(routerAddr, vaultAddr, oracleAddr, usdcAddr, [amznAddr, tslaAddr, spyAddr]);
    const collateralYieldStrategyAddr = await collateralYieldStrategy.getAddress();

    const DefensiveStrategy = await ethers.getContractFactory("DefensiveStrategy");
    defensiveStrategy = await DefensiveStrategy.deploy(routerAddr, vaultAddr, oracleAddr, usdcAddr);
    const defensiveStrategyAddr = await defensiveStrategy.getAddress();

    // Link configurations
    await strategyRouter.setVault(vaultAddr);
    await strategyRouter.setStrategies(lendingStrategyAddr, collateralYieldStrategyAddr, stableYieldStrategyAddr, defensiveStrategyAddr);
    await collateralYieldStrategy.setStableYieldStrategy(stableYieldStrategyAddr);
    await stormController.setStrategyRouter(routerAddr);
    await stormController.setReserveVault(reserveVaultAddr);
    await reserveVault.setVaultAndRouter(vaultAddr, routerAddr);

    // Mint tokens to user for testing
    await usdc.mint(user.address, ethers.parseUnits("10000", 6));
    await amzn.mint(user.address, ethers.parseEther("10"));
    await tsla.connect(deployer).mint(user.address, ethers.parseEther("10"));
  });

  describe("Risk Engine & Allocation Manager", function () {
    it("should calculate correct risk score based on inputs", async function () {
      // Risk Score = 0.35 * volatility + 0.25 * concentration + 0.25 * leverage + 0.15 * healthFactorRisk
      // Default: volatility = 20, concentration = 30, leverage = 10, healthFactorRisk = 15
      // Expected: (35*20 + 25*30 + 25*10 + 15*15)/100 = (700 + 750 + 250 + 225)/100 = 1925 / 100 = 19
      expect(await riskEngine.getRiskScore()).to.equal(19);

      // Update metrics
      // volatility = 80, concentration = 50, leverage = 20, healthFactorRisk = 80
      // Expected: (35*80 + 25*50 + 25*20 + 15*80)/100 = (2800 + 1250 + 500 + 1200)/100 = 5750/100 = 57
      await riskEngine.updateMetrics(80, 50, 20, 80);
      expect(await riskEngine.getRiskScore()).to.equal(57);
    });

    it("should return correct allocations based on risk band", async function () {
      // Low risk (riskScore <= 35): 60% Lending, 30% Stable, 10% Reserve
      let alloc = await allocationManager.getAllocation(19, false);
      expect(alloc.lendingPct).to.equal(60);
      expect(alloc.stablePct).to.equal(30);
      expect(alloc.reservePct).to.equal(10);

      // Medium risk (35 < riskScore <= 75): 40% Lending, 40% Stable, 20% Reserve
      alloc = await allocationManager.getAllocation(57, false);
      expect(alloc.lendingPct).to.equal(40);
      expect(alloc.stablePct).to.equal(40);
      expect(alloc.reservePct).to.equal(20);

      // Storm mode: 25% Lending, 35% Stable, 40% Reserve
      alloc = await allocationManager.getAllocation(57, true);
      expect(alloc.lendingPct).to.equal(25);
      expect(alloc.stablePct).to.equal(35);
      expect(alloc.reservePct).to.equal(40);
    });
  });

  describe("Vault Deposits & Multi-Asset Deposits", function () {
    it("should allow depositing USDC and minting shares", async function () {
      const usdcAmt = ethers.parseUnits("1000", 6);
      const vaultAddr = await vault.getAddress();
      await usdc.connect(user).approve(vaultAddr, usdcAmt);
      
      // Deposit 1000 USDC
      await vault.connect(user).deposit(usdcAmt, user.address);
      
      // Check user share balance (1000 shares, since 1 share = 1 USDC value initially)
      expect(await vault.balanceOf(user.address)).to.equal(ethers.parseUnits("1000", 6));
      expect(await vault.totalAssets()).to.equal(usdcAmt);
    });

    it("should allow multi-asset deposits (USDC + tokenized stocks)", async function () {
      const usdcAmt = ethers.parseUnits("1000", 6); // $1000
      const amznAmt = ethers.parseEther("5"); // 5 AMZN @ $200 = $1000
      const tslaAmt = ethers.parseEther("10"); // 10 TSLA @ $100 = $1000
      // Total value deposited should be $3000

      const vaultAddr = await vault.getAddress();
      await usdc.connect(user).approve(vaultAddr, usdcAmt);
      await amzn.connect(user).approve(vaultAddr, amznAmt);
      await tsla.connect(user).approve(vaultAddr, tslaAmt);

      const tokens = [await usdc.getAddress(), await amzn.getAddress(), await tsla.getAddress()];
      const amounts = [usdcAmt, amznAmt, tslaAmt];

      // Execute multi deposit
      await vault.connect(user).depositMulti(tokens, amounts, user.address);

      // Since base asset is USDC (6 decimals), the $3000 total value is equivalent to 3000 USDC.
      // Expected shares = 3000 shares (scaled by 6 decimals = 3000 * 10^6)
      const expectedShares = ethers.parseUnits("3000", 6);
      expect(await vault.balanceOf(user.address)).to.equal(expectedShares);

      // Confirm total assets is $3000 (scaled by 6 decimals)
      // Since CollateralYieldStrategy borrows 25% USDC ($500 value) and earns 6% simulated yield,
      // total assets will be slightly higher or equal depending on block time.
      expect(await vault.totalAssets()).to.be.closeTo(ethers.parseUnits("3000", 6), ethers.parseUnits("200", 6));
    });
  });

  describe("Storm Mode triggering & Capital protection", function () {
    it("should trigger storm mode and reallocate capital safely", async function () {
      // 1. Initial Deposit of 2000 USDC
      const usdcAmt = ethers.parseUnits("2000", 6);
      await usdc.connect(user).approve(await vault.getAddress(), usdcAmt);
      await vault.connect(user).deposit(usdcAmt, user.address);

      // Confirm distribution based on default Low Risk allocation:
      // 60% Lending ($1200), 30% Stable ($600), 10% Reserve ($200)
      expect(await usdc.balanceOf(await reserveVault.getAddress())).to.equal(ethers.parseUnits("200", 6));
      expect(await lendingMarket.balances(await lendingStrategy.getAddress(), await usdc.getAddress())).to.equal(ethers.parseUnits("1200", 6));
      expect(await lendingMarket.balances(await stableYieldStrategy.getAddress(), await usdc.getAddress())).to.equal(ethers.parseUnits("600", 6));

      // 2. Trigger Storm Mode via manual override
      await stormController.setManualOverride(true);
      expect(await stormController.isStormMode()).to.be.true;

      // Confirm rebalancing occurred and funds moved to safe allocations:
      // Storm Mode allocation: 25% Lending ($500), 35% Stable ($700), 40% Reserve ($800)
      // During Storm mode rebalance, the strategy router pulls everything and splits strategy allocation:
      // strategy allocation is Lending (25%) + Stable (35%) = 60% of total ($1200).
      // Router splits strategy USDC: 60% to defensive strategy ($720) and 40% to stable yield strategy ($480).
      // Reserve gets 40% ($800).
      expect(await usdc.balanceOf(await reserveVault.getAddress())).to.equal(ethers.parseUnits("800", 6));
      expect(await defensiveStrategy.localBalance()).to.equal(ethers.parseUnits("720", 6));
    });
  });
});
