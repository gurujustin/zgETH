// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { Addresses } from "contracts/utils/Addresses.sol";

contract TransferOwnership is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        console.log("Deploying on mainnet deployer: %s", msg.sender);
        vm.startBroadcast(deployerPrivateKey);

        // Contracts that need to be transferred
        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        address currentProxyOwner = proxyAdmin.owner();
        console.log("Current owner of ProxyAdmin: ", currentProxyOwner);

        // Manager is gonna same as admin for now
        address multisig = Addresses.ADMIN_MULTISIG;

        if (block.chainid == 1) {
            LRTConfig lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
            /**
             * ################# Grant Permissions to Multi-sig
             */
            // LRTConfig
            lrtConfig.grantRole(LRTConstants.MANAGER, multisig);
            lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, multisig);
            lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, multisig);
            console.log("[LRTConfig] Manager, Operator & Admin permission granted to: ", multisig);

            /**
             * ################# Revoke Permissions for existing owner
             */
            lrtConfig.revokeRole(LRTConstants.MANAGER, currentProxyOwner);
            lrtConfig.revokeRole(LRTConstants.OPERATOR_ROLE, currentProxyOwner);
            lrtConfig.revokeRole(LRTConstants.DEFAULT_ADMIN_ROLE, currentProxyOwner);
            console.log("[LRTConfig] Revoked roles from current owner");
        }

        /**
         * ################# Transfer Ownership to multisig
         */
        proxyAdmin.transferOwnership(multisig);
        console.log("ProxyAdmin ownership transferred to: ", multisig);

        vm.stopBroadcast();
    }
}
