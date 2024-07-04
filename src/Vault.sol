// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

// vault skeleton from sDAI https://github.com/makerdao/sdai/blob/3d0a270536d1adab591a1b38be8018040fbb50b2/src/SNst.sol
contract Vault {
    // ERC20
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public price; // wad
    address public asset;

    // ERC4626
    uint256 public totalAssets;

    // --- Constants ---
    uint256 constant SCALE = 10 ** 18;

    // --- Events ---

    // ERC20
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    // ERC4626
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    // --- Constructor ---

    constructor(address token) {
        // start with a price different from 1.0 as a 1.0 price does not cause rounding issues.
        totalSupply = 100;
        totalAssets = 101;
        asset = token;
    }

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // Note: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    // --- ERC20 Mutations ---

    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0) && to != address(this), "Vault/invalid-address");
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "Vault/insufficient-balance");

        unchecked {
            balanceOf[msg.sender] = balance - value;
            balanceOf[to] += value; // note: we don't need an overflow check here b/c sum of all balances == totalSupply
        }

        emit Transfer(msg.sender, to, value);

        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(to != address(0) && to != address(this), "Vault/invalid-address");
        uint256 balance = balanceOf[from];
        require(balance >= value, "Vault/insufficient-balance");

        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "Vault/insufficient-allowance");

                unchecked {
                    allowance[from][msg.sender] = allowed - value;
                }
            }
        }

        unchecked {
            balanceOf[from] = balance - value;
            balanceOf[to] += value; // note: we don't need an overflow check here b/c sum of all balances == totalSupply
        }

        emit Transfer(from, to, value);

        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    // --- Mint/Burn Internal ---

    function _mint(uint256 assets, uint256 shares, address receiver) internal {
        require(receiver != address(0) && receiver != address(this), "Vault/invalid-address");

        IERC20(asset).transferFrom(msg.sender, address(this), assets);
        totalAssets += assets;

        unchecked {
            balanceOf[receiver] = balanceOf[receiver] + shares; // note: we don't need an overflow check here b/c balanceOf[receiver] <= totalSupply
            totalSupply = totalSupply + shares; // note: we don't need an overflow check here b/c shares totalSupply will always be <= totalSupply
        }

        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
    }

    function _burn(uint256 assets, uint256 shares, address receiver, address owner) internal {
        uint256 balance = balanceOf[owner];
        require(balance >= shares, "Vault/insufficient-balance");

        if (owner != msg.sender) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= shares, "Vault/insufficient-allowance");

                unchecked {
                    allowance[owner][msg.sender] = allowed - shares;
                }
            }
        }

        unchecked {
            balanceOf[owner] = balance - shares; // note: we don't need overflow checks b/c require(balance >= shares) and balance <= totalSupply
            totalSupply = totalSupply - shares;
        }

        IERC20(asset).transfer(receiver, assets);
        totalAssets -= assets;

        emit Transfer(owner, address(0), shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // --- ERC-4626 ---
    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets * SCALE / getPrice();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares * getPrice() / SCALE;
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = assets * SCALE / getPrice();
        _mint(assets, shares, receiver);
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        return _divup(shares * getPrice(), SCALE);
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = _divup(shares * getPrice(), SCALE);
        _mint(assets, shares, receiver);
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return _divup(assets * SCALE, getPrice());
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        shares = _divup(assets * SCALE, getPrice());
        _burn(assets, shares, receiver, owner);
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf[owner];
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        assets = shares * getPrice() / SCALE;
        _burn(assets, shares, receiver, owner);
    }

    function getPrice() public view returns (uint256) {
        return totalAssets * SCALE / totalSupply;
    }

    function mockError() public view returns (uint256) {
        // this is an example of why increasing the share price might be bad.
        // this calculation only works as long as the share price is in range of [0, 1e36].abi
        uint256 shares = type(uint144).max;
        return shares * getPrice() / SCALE;
    }
}
