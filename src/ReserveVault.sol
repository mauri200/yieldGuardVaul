// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IMockDecimals.sol";

contract ReserveVault is Ownable {
    using SafeERC20 for IERC20;

    address public vault;
    address public strategyRouter;

    address[] public supportedTokens;
    mapping(address => bool) public isSupportedToken;

    // Reserve tracking percentages
    uint256 public normalReservePercent = 10;
    uint256 public stormReservePercent = 25;

    event VaultUpdated(address newVault);
    event StrategyRouterUpdated(address newRouter);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);
    event ReservePercentUpdated(uint256 normalReserve, uint256 stormReserve);

    modifier onlyVaultOrRouter() {
        require(msg.sender == vault || msg.sender == strategyRouter || msg.sender == owner(), "ReserveVault: unauthorized");
        _;
    }

    constructor(address[] memory _supportedTokens) Ownable(msg.sender) {
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            address token = _supportedTokens[i];
            supportedTokens.push(token);
            isSupportedToken[token] = true;
        }
    }

    function setVaultAndRouter(address _vault, address _strategyRouter) external onlyOwner {
        vault = _vault;
        strategyRouter = _strategyRouter;
        emit VaultUpdated(_vault);
        emit StrategyRouterUpdated(_strategyRouter);
    }

    function updateReservePercentages(uint256 _normal, uint256 _storm) external onlyOwner {
        require(_normal <= 100 && _storm <= 100, "ReserveVault: invalid percentages");
        normalReservePercent = _normal;
        stormReservePercent = _storm;
        emit ReservePercentUpdated(_normal, _storm);
    }

    function withdraw(address token, address to, uint256 amount) external onlyVaultOrRouter {
        require(isSupportedToken[token], "ReserveVault: unsupported token");
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 toWithdraw = amount > balance ? balance : amount;
        if (toWithdraw > 0) {
            IERC20(token).safeTransfer(to, toWithdraw);
            emit TokenWithdrawn(token, to, toWithdraw);
        }
    }

    function totalValue(address oracleAddress) public view returns (uint256) {
        IPriceOracle oracle = IPriceOracle(oracleAddress);
        uint256 totalUSD = 0;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                uint256 price = oracle.getPrice(token); // 18 decimals
                
                uint8 dec = 18;
                try IMockDecimals(token).decimals() returns (uint8 d) {
                    dec = d;
                } catch {
                    dec = 18;
                }
                
                uint256 usdValue = (balance * price) / (10 ** dec);
                totalUSD += usdValue;
            }
        }
        return totalUSD;
    }
}
