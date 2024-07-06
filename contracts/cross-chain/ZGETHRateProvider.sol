// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { CrossChainRateProvider } from "./CrossChainRateProvider.sol";

import { IXZerogDeposit } from "../bridge/L2/IXZerogDeposit.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title zgETH cross chain rate provider
/// @notice Provides the current exchange rate of zgETH to a receiver contract on a different chain than the one this
/// contract is deployed on
contract ZGETHRateProvider is CrossChainRateProvider {
    address public xzerogDeposit;
    address public chainlinkOracle;

    constructor(address _xzerogDeposit, uint16 _dstChainId, address _layerZeroEndpoint, address _chainlinkOracle) {
        xzerogDeposit = _xzerogDeposit;

        rateInfo = RateInfo({
            tokenSymbol: "zgETH",
            tokenAddress: 0xA5E5A6724E99EaBd4CA236633AAb882B7658F287, // zgETH token address on Arbitrum
            baseTokenSymbol: "ETH",
            baseTokenAddress: address(0) // Address 0 for native tokens
         });
        dstChainId = _dstChainId;
        layerZeroEndpoint = _layerZeroEndpoint;
        chainlinkOracle = _chainlinkOracle;
    }

    /// @notice Returns the latest rate from the zgETH contract
    function getLatestRate() public view override returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(chainlinkOracle);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 frxETHDETHprice = uint256(price) * 1e18 / 10 ** uint256(priceFeed.decimals());
        return IXZerogDeposit(xzerogDeposit).lastPrice() * 1e18 / frxETHDETHprice;
    }
}