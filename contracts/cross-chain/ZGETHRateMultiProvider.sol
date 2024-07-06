// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { MultiChainRateProvider } from "./MultiChainRateProvider.sol";

import { ILRTOracle } from "../interfaces/ILRTOracle.sol";

/// @title zgETH cross chain rate provider
/// @notice Provides the current exchange rate of zgETH to a receiver contract on a different chain than the one this
/// contract is deployed on
contract ZGETHRateMultiProvider is MultiChainRateProvider {
    address public zgETHPriceOracle;

    constructor(address _zgETHPriceOracle) {
        zgETHPriceOracle = _zgETHPriceOracle;

        rateInfo = RateInfo({
            tokenSymbol: "zgETH",
            tokenAddress: 0x17fdeB2fbB8089fea8a7BDb847E49ce67cF863df, // zgETH token address on ETH mainnet
            baseTokenSymbol: "ETH",
            baseTokenAddress: address(0) // Address 0 for native tokens
         });
    }

    /// @notice Returns the latest rate from the zgETH contract
    function getLatestRate() public view override returns (uint256) {
        return ILRTOracle(zgETHPriceOracle).zgETHPrice();
    }
}
