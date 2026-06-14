// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PriceOracle is IPriceOracle, Ownable {
    mapping(address => uint256) private _prices;

    event PriceUpdated(address indexed token, uint256 price);

    constructor() Ownable(msg.sender) {}

    function setPrice(address token, uint256 price) external onlyOwner {
        _prices[token] = price;
        emit PriceUpdated(token, price);
    }

    function getPrice(address token) external view override returns (uint256) {
        uint256 price = _prices[token];
        require(price > 0, "PriceOracle: price not set");
        return price;
    }
}
