// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseStrategy.sol";

contract DefensiveStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    address public usdcToken;
    uint256 public localBalance;

    constructor(
        address _strategyRouter,
        address _vault,
        address _oracle,
        address _usdcToken
    ) BaseStrategy(_strategyRouter, _vault, _oracle) {
        usdcToken = _usdcToken;
    }

    function deposit(address token, uint256 amount) external override onlyRouterOrVault {
        require(token == usdcToken, "DefensiveStrategy: only USDC supported");
        if (amount > 0) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            localBalance += amount;
            emit Deposited(token, amount);
        }
    }

    function withdraw(address token, address to, uint256 amount) external override onlyRouterOrVault {
        require(token == usdcToken, "DefensiveStrategy: only USDC supported");
        uint256 toWithdraw = amount > localBalance ? localBalance : amount;
        if (toWithdraw > 0) {
            localBalance -= toWithdraw;
            IERC20(token).safeTransfer(to, toWithdraw);
            emit Withdrawn(token, to, toWithdraw);
        }
    }

    function totalAssets() external view override returns (uint256) {
        if (localBalance > 0) {
            uint256 price = oracle.getPrice(usdcToken);
            uint8 dec = getTokenDecimals(usdcToken);
            return (localBalance * price) / (10 ** dec);
        }
        return 0;
    }

    function harvest() external override onlyRouterOrVault {
        emit Harvested(0);
    }

    function emergencyWithdraw() external override onlyRouterOrVault {
        uint256 bal = IERC20(usdcToken).balanceOf(address(this));
        if (bal > 0) {
            localBalance = 0;
            IERC20(usdcToken).safeTransfer(vault, bal);
        }
        emit EmergencyWithdrawExecuted();
    }
}
