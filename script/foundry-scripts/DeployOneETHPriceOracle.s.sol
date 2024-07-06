// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

import { OneETHPriceOracle } from "contracts/oracles/OneETHPriceOracle.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract DeployOneETHPriceOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked("Zerog-Staked"));

        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);

        // Deploy the new contract
        address newImpl = address(new OneETHPriceOracle());
        console.log("OneETHPriceOracle implementation deployed at: %s", newImpl);

        OneETHPriceOracle proxy = OneETHPriceOracle(proxyFactory.create(address(newImpl), address(proxyAdmin), salt));

        LRTOracle oracle = LRTOracle(Addresses.LRT_ORACLE);
        oracle.updatePriceOracleFor(Addresses.ETH, address(proxy));

        vm.stopBroadcast();
    }
}
