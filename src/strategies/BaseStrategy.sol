// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../PriceOracle.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IMockDecimals.sol";

abstract contract BaseStrategy is IStrategy, Ownable {
    using SafeERC20 for IERC20;

    address public strategyRouter;
    address public vault;
    PriceOracle public oracle;

    event Deposited(address indexed token, uint256 amount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event Harvested(uint256 yieldUSD);
    event EmergencyWithdrawExecuted();

    modifier onlyRouterOrVault() {
        require(msg.sender == strategyRouter || msg.sender == vault || msg.sender == owner(), "Strategy: unauthorized");
        _;
    }

    constructor(address _strategyRouter, address _vault, address _oracle) Ownable(msg.sender) {
        strategyRouter = _strategyRouter;
        vault = _vault;
        oracle = PriceOracle(_oracle);
    }

    function deposit(address token, uint256 amount) external virtual override onlyRouterOrVault {}
    function withdraw(address token, address to, uint256 amount) external virtual override onlyRouterOrVault {}
    function totalAssets() external view virtual override returns (uint256) { return 0; }
    function harvest() external virtual override onlyRouterOrVault {}
    function emergencyWithdraw() external virtual override onlyRouterOrVault {}

    function getTokenDecimals(address token) internal view returns (uint8) {
        try IMockDecimals(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }
}
