// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeNodeDelegator is Script {
    ProxyAdmin public proxyAdmin;
    LRTConfig public lrtConfig;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        lrtConfig = LRTConfig(Addresses.LRT_CONFIG);

        // deploy implementation contracts
        address nodeDelegatorImplementation = address(new NodeDelegator());

        // upgrade implementation
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(0x098AB95c7f5B8eF194460A849f77F13a1Ed0bA39), nodeDelegatorImplementation
        );

        // lrtConfig.setContract(LRTConstants.SSV_TOKEN, 0x9D65fF81a3c488d585bBfb0Bfe3c7707c7917f54);
        // lrtConfig.setContract(LRTConstants.SSV_NETWORK, 0xDD9BC35aE942eF0cFa76930954a156B3fF30a4E1);
        lrtConfig.setContract(LRTConstants.BEACON_CHAIN_ETH_STRATEGY, 0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0);

        // lrtConfig.setContract(LRTConstants.SSV_TOKEN, 0xad45A78180961079BFaeEe349704F411dfF947C6);
        // lrtConfig.setContract(LRTConstants.SSV_NETWORK, 0x38A4794cCEd47d3baf7370CcC43B560D3a1beEFA);

        vm.stopBroadcast();
    }
}
