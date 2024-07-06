// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ZGETHRateProvider } from "contracts/cross-chain/ZGETHRateProvider.sol";
import { ZGETHRateReceiver } from "contracts/cross-chain/ZGETHRateReceiver.sol";

contract DeployZGETHRateProvider is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        if (block.chainid != 42_161) {
            revert("Must be deployed on arbitrum");
        }

        address zgETHOracle = 0xae69f9AC9aC9302E2F97B313CaF1fB45a9bB18A6;
        uint16 layerZeroDstChainId = 255; // Layer Zero id for Fraxtal
        address layerZeroEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        address chainlinkOracle = 0x5C3e80763862CB777Aa07BDDBcCE0123104e1c34;

        address zgETHRateProviderContractAddress =
            address(new ZGETHRateProvider(zgETHOracle, layerZeroDstChainId, layerZeroEndpoint, chainlinkOracle));

        console.log("ZGETHRateProvider deployed at: %s", address(zgETHRateProviderContractAddress));

        vm.stopBroadcast();
    }
}

contract DeployZGETHRateReceiver is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        if (block.chainid != 252) {
            revert("Must be deployed on Arbitrum");
        }

        uint16 layerZeroSrcChainId = 110; // Layer Zero id for Arbitrum
        address rateProviderOnEthMainnet = 0xf980586D60043D8B8B8A136C8B23e76C5A2C826D;
        address layerZeroEndpoint = 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7; // LZ endpoint for Fraxtal

        address zgETHRateReceiverContractAddress =
            address(new ZGETHRateReceiver(layerZeroSrcChainId, rateProviderOnEthMainnet, layerZeroEndpoint));

        console.log("ZGETHRateReceiver deployed at: %s", address(zgETHRateReceiverContractAddress));

        vm.stopBroadcast();
    }
}
