# Rounding Errors Compounding Example

The repo tries to explore how exponentially compounding rounding errors can be caught with better tooling.

This example shows a vault and let's assume we don't want the vault share price to be able to increase too high for whatever reason (see `Vault.mockError()`).
The test shows an initial share price inflation attack using moderate funds to increase the share price by several orders of magnitude.
The interesting part is that the number of `deposit` calls required to double the price is logarithmacially, i.e., the share price inflates exponentially with the number of `deposit` iterations. This is because the rounding error for the deposit calculation `deposit * 1e18 / price` leaves an asset donation of the `price (/ 1e18)` itself. Initially, at the price of `1.0` this is just `1` token, but once the share price crosses `2.0`, it will be `2` tokens, etc.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```
