// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/PriceOracle.sol";
import "../src/RiskEngine.sol";
import "../src/AllocationManager.sol";
import "../src/StormController.sol";
import "../src/ReserveVault.sol";
import "../src/StrategyRouter.sol";
import "../src/YieldGuardVault.sol";
import "../src/AssetRegistry.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockLendingMarket.sol";
import "../src/strategies/LendingStrategy.sol";
import "../src/strategies/StableYieldStrategy.sol";
import "../src/strategies/CollateralYieldStrategy.sol";
import "../src/strategies/DefensiveStrategy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        address usdcAddr;
        address amznAddr;
        address tslaAddr;
        address pltrAddr;
        address nflxAddr;
        address amdAddr;

        // Check if we are on Robinhood Chain Testnet (Chain ID 11111)
        if (block.chainid == 46630) {
            console.log("Deploying to Robinhood Chain Testnet...");
            usdcAddr = 0x7E955252E15c84f5768B83c41a71F9eba181802F; // USDG used as base stablecoin
            amznAddr = 0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02;
            tslaAddr = 0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E;
            pltrAddr = 0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0;
            nflxAddr = 0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93;
            amdAddr  = 0x71178BAc73cBeb415514eB542a8995b82669778d;
        } else {
            console.log("Deploying mock tokens to local/unrecognized network...");
            MockERC20 mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
            MockERC20 mockAMZN = new MockERC20("Mock Amazon", "AMZN", 18);
            MockERC20 mockTSLA = new MockERC20("Mock Tesla", "TSLA", 18);
            MockERC20 mockPLTR = new MockERC20("Mock Palantir", "PLTR", 18);
            MockERC20 mockNFLX = new MockERC20("Mock Netflix", "NFLX", 18);
            MockERC20 mockAMD  = new MockERC20("Mock AMD", "AMD", 18);

            usdcAddr = address(mockUSDC);
            amznAddr = address(mockAMZN);
            tslaAddr = address(mockTSLA);
            pltrAddr = address(mockPLTR);
            nflxAddr = address(mockNFLX);
            amdAddr  = address(mockAMD);
        }

        console.log("Base Stablecoin:", usdcAddr);
        console.log("AMZN Token:", amznAddr);
        console.log("TSLA Token:", tslaAddr);
        console.log("PLTR Token:", pltrAddr);
        console.log("NFLX Token:", nflxAddr);
        console.log("AMD Token:", amdAddr);

        // 2. Deploy Mock Lending Market
        MockLendingMarket lendingMarket = new MockLendingMarket();
        address lendingMarketAddr = address(lendingMarket);
        console.log("MockLendingMarket deployed to:", lendingMarketAddr);

        // 3. Deploy Price Oracle
        PriceOracle oracle = new PriceOracle();
        address oracleAddr = address(oracle);
        console.log("PriceOracle deployed to:", oracleAddr);

        // Set default prices (scaled to 18 decimals)
        oracle.setPrice(usdcAddr, 1.00 * 10**18); // USDC/USDG
        oracle.setPrice(amznAddr, 180.00 * 10**18);
        oracle.setPrice(tslaAddr, 170.00 * 10**18);
        oracle.setPrice(pltrAddr, 30.00 * 10**18);
        oracle.setPrice(nflxAddr, 600.00 * 10**18);
        oracle.setPrice(amdAddr,  160.00 * 10**18);
        console.log("Initial oracle prices set.");

        // 4. Deploy Risk Engine
        RiskEngine riskEngine = new RiskEngine();
        address riskEngineAddr = address(riskEngine);
        console.log("RiskEngine deployed to:", riskEngineAddr);

        // 5. Deploy Allocation Manager
        AllocationManager allocationManager = new AllocationManager();
        address allocationManagerAddr = address(allocationManager);
        console.log("AllocationManager deployed to:", allocationManagerAddr);

        // 6. Deploy Storm Controller
        StormController stormController = new StormController(riskEngineAddr);
        address stormControllerAddr = address(stormController);
        console.log("StormController deployed to:", stormControllerAddr);

        // 7. Deploy Reserve Vault
        address[] memory supportedInReserve = new address[](6);
        supportedInReserve[0] = usdcAddr;
        supportedInReserve[1] = amznAddr;
        supportedInReserve[2] = tslaAddr;
        supportedInReserve[3] = pltrAddr;
        supportedInReserve[4] = nflxAddr;
        supportedInReserve[5] = amdAddr;
        ReserveVault reserveVault = new ReserveVault(supportedInReserve);
        address reserveVaultAddr = address(reserveVault);
        console.log("ReserveVault deployed to:", reserveVaultAddr);

        // 8. Deploy Strategy Router
        address[] memory supportedStocks = new address[](5);
        supportedStocks[0] = amznAddr;
        supportedStocks[1] = tslaAddr;
        supportedStocks[2] = pltrAddr;
        supportedStocks[3] = nflxAddr;
        supportedStocks[4] = amdAddr;
        StrategyRouter strategyRouter = new StrategyRouter(
            allocationManagerAddr,
            stormControllerAddr,
            reserveVaultAddr,
            oracleAddr,
            usdcAddr,
            supportedStocks
        );
        address routerAddr = address(strategyRouter);
        console.log("StrategyRouter deployed to:", routerAddr);

        // 9. Deploy Asset Registry
        AssetRegistry assetRegistry = new AssetRegistry();
        address assetRegistryAddr = address(assetRegistry);
        console.log("AssetRegistry deployed to:", assetRegistryAddr);

        // 10. Deploy YieldGuardVault (ERC-4626)
        YieldGuardVault vault = new YieldGuardVault(
            IERC20(usdcAddr),
            oracleAddr,
            reserveVaultAddr,
            routerAddr,
            assetRegistryAddr
        );
        address vaultAddr = address(vault);
        console.log("YieldGuardVault deployed to:", vaultAddr);

        // 11. Deploy Strategies
        address[] memory lendingStrategyTokens = new address[](1);
        lendingStrategyTokens[0] = usdcAddr;
        LendingStrategy lendingStrategy = new LendingStrategy(
            routerAddr,
            vaultAddr,
            oracleAddr,
            lendingMarketAddr,
            lendingStrategyTokens
        );
        address lendingStrategyAddr = address(lendingStrategy);

        StableYieldStrategy stableYieldStrategy = new StableYieldStrategy(
            routerAddr,
            vaultAddr,
            oracleAddr,
            lendingMarketAddr,
            usdcAddr
        );
        address stableYieldStrategyAddr = address(stableYieldStrategy);

        CollateralYieldStrategy collateralYieldStrategy = new CollateralYieldStrategy(
            routerAddr,
            vaultAddr,
            oracleAddr,
            usdcAddr,
            supportedStocks
        );
        address collateralYieldStrategyAddr = address(collateralYieldStrategy);

        DefensiveStrategy defensiveStrategy = new DefensiveStrategy(
            routerAddr,
            vaultAddr,
            oracleAddr,
            usdcAddr
        );
        address defensiveStrategyAddr = address(defensiveStrategy);

        console.log("Strategies deployed with correct vault association.");

        // 12. Configure Asset Registry
        assetRegistry.registerAsset(usdcAddr);
        assetRegistry.registerAsset(amznAddr);
        assetRegistry.registerAsset(tslaAddr);
        assetRegistry.registerAsset(pltrAddr);
        assetRegistry.registerAsset(nflxAddr);
        assetRegistry.registerAsset(amdAddr);
        console.log("Assets registered in AssetRegistry.");

        // 13. Configure StrategyRouter
        strategyRouter.setVault(vaultAddr);
        strategyRouter.setStrategies(
            lendingStrategyAddr,
            collateralYieldStrategyAddr,
            stableYieldStrategyAddr,
            defensiveStrategyAddr
        );
        console.log("StrategyRouter configured with strategies.");

        // 14. Configure CollateralYieldStrategy
        collateralYieldStrategy.setStableYieldStrategy(stableYieldStrategyAddr);

        // 15. Configure StormController
        stormController.setStrategyRouter(routerAddr);
        stormController.setReserveVault(reserveVaultAddr);

        // 16. Configure ReserveVault
        reserveVault.setVaultAndRouter(vaultAddr, routerAddr);
        console.log("Protocol configurations completed.");

        // Mint mock tokens to deployer for local testing only
        if (block.chainid != 46630) {
            MockERC20(usdcAddr).mint(deployer, 100000 * 10**6);
            MockERC20(amznAddr).mint(deployer, 1000 * 10**18);
            MockERC20(tslaAddr).mint(deployer, 1000 * 10**18);
            MockERC20(pltrAddr).mint(deployer, 1000 * 10**18);
            MockERC20(nflxAddr).mint(deployer, 1000 * 10**18);
            MockERC20(amdAddr).mint(deployer, 1000 * 10**18);
            console.log("Mock tokens minted for test account.");
        }

        vm.stopBroadcast();

        // 17. Save deployed addresses to frontend
        string memory parent = "parent";
        vm.serializeAddress(parent, "USDC", usdcAddr);
        vm.serializeAddress(parent, "AMZN", amznAddr);
        vm.serializeAddress(parent, "TSLA", tslaAddr);
        vm.serializeAddress(parent, "PLTR", pltrAddr);
        vm.serializeAddress(parent, "NFLX", nflxAddr);
        vm.serializeAddress(parent, "AMD", amdAddr);
        vm.serializeAddress(parent, "MockLendingMarket", lendingMarketAddr);
        vm.serializeAddress(parent, "PriceOracle", oracleAddr);
        vm.serializeAddress(parent, "RiskEngine", riskEngineAddr);
        vm.serializeAddress(parent, "AllocationManager", allocationManagerAddr);
        vm.serializeAddress(parent, "StormController", stormControllerAddr);
        vm.serializeAddress(parent, "ReserveVault", reserveVaultAddr);
        vm.serializeAddress(parent, "StrategyRouter", routerAddr);
        vm.serializeAddress(parent, "LendingStrategy", lendingStrategyAddr);
        vm.serializeAddress(parent, "StableYieldStrategy", stableYieldStrategyAddr);
        vm.serializeAddress(parent, "CollateralYieldStrategy", collateralYieldStrategyAddr);
        vm.serializeAddress(parent, "DefensiveStrategy", defensiveStrategyAddr);
        vm.serializeAddress(parent, "AssetRegistry", assetRegistryAddr);
        string memory finalJson = vm.serializeAddress(parent, "YieldGuardVault", vaultAddr);

//        vm.writeJson(finalJson, "./frontend/src/contracts/addresses.json");
//        console.log("Deployed addresses saved to frontend/src/contracts/addresses.json");
    }
}
