// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { XZerogBridge } from "contracts/bridge/L1/XZerogBridge.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract UpgradeBridgeOrigin is Script {
    ProxyAdmin public proxyAdmin;
    XZerogBridge public xZerogBridge;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        xZerogBridge = XZerogBridge(payable(Addresses.BRIDGE));

        address xZerogBridgeImp = address(new XZerogBridge());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.BRIDGE), xZerogBridgeImp);

        xZerogBridge.setLrtConfig(Addresses.LRT_CONFIG);

        vm.stopBroadcast();
    }
}
