// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AssetRegistry
 * @dev Registry of supported ERC20 assets (real Robinhood Chain tokenized stocks).
 * Only the owner can add or remove assets. Other contracts can query support.
 */
contract AssetRegistry is Ownable {
    // Mapping of token address => supported flag
    mapping(address => bool) private _supported;
    // List of supported assets for enumeration
    address[] private _assets;

    constructor() Ownable(msg.sender) {}

    event AssetRegistered(address indexed token);
    event AssetRemoved(address indexed token);

    /**
     * @dev Register a new ERC20 token as supported.
     * Reverts if already registered.
     */
    function registerAsset(address token) external onlyOwner {
        require(token != address(0), "AssetRegistry: zero address");
        require(!_supported[token], "AssetRegistry: already supported");
        _supported[token] = true;
        _assets.push(token);
        emit AssetRegistered(token);
    }

    /**
     * @dev Remove a supported token.
     * Note: the token is removed from the internal list by swapping with the last element.
     */
    function removeAsset(address token) external onlyOwner {
        require(_supported[token], "AssetRegistry: not supported");
        _supported[token] = false;
        // Remove from array
        uint256 len = _assets.length;
        for (uint256 i = 0; i < len; i++) {
            if (_assets[i] == token) {
                _assets[i] = _assets[len - 1];
                _assets.pop();
                break;
            }
        }
        emit AssetRemoved(token);
    }

    /**
     * @dev Returns true if the token is supported.
     */
    function isSupported(address token) external view returns (bool) {
        return _supported[token];
    }

    /**
     * @dev Returns the list of all supported asset addresses.
     */
    function getSupportedAssets() external view returns (address[] memory) {
        return _assets;
    }
}
