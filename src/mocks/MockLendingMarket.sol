// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockLendingMarket {
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256)) public depositTimes;

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender][token] += amount;
        depositTimes[msg.sender][token] = block.timestamp;
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        require(balances[msg.sender][token] >= amount, "Insufficient balance");
        
        uint256 interest = calculateInterest(msg.sender, token, amount);
        balances[msg.sender][token] -= amount;
        
        // Transfer back the original amount + mock interest
        IERC20(token).transfer(msg.sender, amount + interest);
        emit Withdrawn(msg.sender, token, amount + interest);
    }

    function calculateInterest(address user, address token, uint256 amount) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - depositTimes[user][token];
        if (timeElapsed == 0) return 0;
        // 5% APY: interest = amount * 5 * timeElapsed / (100 * 365 days)
        // For testing purposes, we also add a small block interest to make it visible
        uint256 timeInterest = (amount * 5 * timeElapsed) / (100 * 365 days);
        uint256 fixedPerBlock = (amount * 1) / 100000; // Small fixed interest for immediate feedback
        return timeInterest + fixedPerBlock;
    }
}
