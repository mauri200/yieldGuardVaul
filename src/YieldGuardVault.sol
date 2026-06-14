// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PriceOracle.sol";
import "./ReserveVault.sol";
import "./StrategyRouter.sol";
import "./AssetRegistry.sol";
import "./interfaces/IMockDecimals.sol";
contract YieldGuardVault is ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;

    PriceOracle public oracle;
    ReserveVault public reserveVault;
    StrategyRouter public strategyRouter;
    AssetRegistry public assetRegistry;

    event MultiDeposit(
        address indexed caller,
        address indexed receiver,
        address[] tokens,
        uint256[] amounts,
        uint256 shares
    );

    event MultiWithdraw(
        address indexed caller,
        address indexed receiver,
        address[] tokens,
        uint256[] shares,
        uint256[] amountsOut
    );

    constructor(
        IERC20 _usdc,
        address _oracle,
        address _reserveVault,
        address _strategyRouter,
        address _assetRegistry
    )
        ERC20("YieldGuard Shares", "YGS")
        ERC4626(_usdc)
    {
        oracle = PriceOracle(_oracle);
        reserveVault = ReserveVault(_reserveVault);
        strategyRouter = StrategyRouter(_strategyRouter);
        assetRegistry = AssetRegistry(_assetRegistry);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 totalUSD = reserveVault.totalValue(address(oracle)) + strategyRouter.totalAssets();
        uint8 usdcDec = getTokenDecimals(asset());
        return totalUSD / (10 ** (18 - usdcDec));
    }

    function depositMulti(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address receiver
    ) external nonReentrant returns (uint256 shares) {
        require(tokens.length == amounts.length, "Vault: arrays length mismatch");
        uint256 totalValUSD = 0;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];
            // Ensure token is whitelisted
            require(assetRegistry.isSupported(token), "YieldGuardVault: unsupported asset");
            if (amount == 0) continue;
            
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            
            uint256 price = oracle.getPrice(token);
            uint8 dec = getTokenDecimals(token);
            totalValUSD += (amount * price) / (10 ** dec);
            
            IERC20(token).approve(address(strategyRouter), amount);
            strategyRouter.deposit(token, amount);
        }
        
        uint8 usdcDec = getTokenDecimals(asset());
        uint256 baseAssetEquivalent = totalValUSD / (10 ** (18 - usdcDec));
        
        shares = previewDeposit(baseAssetEquivalent);
        _mint(receiver, shares);
        
        emit MultiDeposit(msg.sender, receiver, tokens, amounts, shares);
    }

    function redeemMulti(
        address[] calldata tokens,
        uint256[] calldata shareAmounts,
        address receiver
    ) external nonReentrant returns (uint256[] memory amountsOut) {
        require(tokens.length == shareAmounts.length, "Vault: arrays length mismatch");
        amountsOut = new uint256[](tokens.length);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 shares = shareAmounts[i];
            if (shares == 0) continue;
            
            require(balanceOf(msg.sender) >= shares, "Vault: insufficient share balance");
            
            _burn(msg.sender, shares);
            
            uint256 baseAssetVal = previewRedeem(shares);
            uint8 usdcDec = getTokenDecimals(asset());
            uint256 valUSD = baseAssetVal * (10 ** (18 - usdcDec)); // 18 decimals
            
            uint256 price = oracle.getPrice(token);
            uint8 tokenDec = getTokenDecimals(token);
            uint256 amountToken = (valUSD * (10 ** tokenDec)) / price;
            
            strategyRouter.withdraw(token, receiver, amountToken);
            amountsOut[i] = amountToken;
        }
        
        emit MultiWithdraw(msg.sender, receiver, tokens, shareAmounts, amountsOut);
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);
        IERC20(asset()).approve(address(strategyRouter), assets);
        strategyRouter.deposit(asset(), assets);
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (caller != owner) {
            _approve(owner, caller, allowance(owner, caller) - shares);
        }
        _burn(owner, shares);
        strategyRouter.withdraw(asset(), receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function getTokenDecimals(address token) internal view returns (uint8) {
        try IMockDecimals(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }
}
