// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTWithdrawalManager } from "contracts/LRTWithdrawalManager.sol";
import { LRTUnstakingVault } from "contracts/LRTUnstakingVault.sol";
import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployWithdrawal is Script {
    ProxyAdmin public proxyAdmin;
    ProxyFactory public proxyFactory;

    LRTWithdrawalManager public lrtWithdrawalProxy;
    LRTUnstakingVault public lrtUnstakingProxy;
    LRTConfig public lrtConfig;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked("Zerog-Staked"));

        proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        lrtConfig = LRTConfig(Addresses.LRT_CONFIG);

        // deploy implementation contracts
        address lrtWithdrawalImplementation = address(new LRTWithdrawalManager());

        // upgrade implementation
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(0xCD5ac07D09C86dc4B34e8A8cE5563dDd97905325), lrtWithdrawalImplementation
        );
        // address lrtUnstakingImplementation = address(new LRTUnstakingVault());

        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        // console.log("LRTWithdrawalManager implementation deployed at: ", lrtWithdrawalImplementation);
        // console.log("LRTUnstakingVault implementation deployed at: ", lrtUnstakingImplementation);
        // console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // lrtWithdrawalProxy = LRTWithdrawalManager(
        //     payable(proxyFactory.create(address(lrtWithdrawalImplementation), address(proxyAdmin), salt))
        // );
        // lrtWithdrawalProxy.initialize(Addresses.LRT_CONFIG);

        // lrtUnstakingProxy = LRTUnstakingVault(
        //     payable(proxyFactory.create(address(lrtUnstakingImplementation), address(proxyAdmin), salt))
        // );
        // lrtUnstakingProxy.initialize(Addresses.LRT_CONFIG);

        // console.log("LRTWithdrawalManager proxy deployed at: ", address(lrtWithdrawalProxy));
        // console.log("LRTUnstakingVault proxy deployed at: ", address(lrtUnstakingProxy));

        // lrtConfig.setContract(LRTConstants.LRT_WITHDRAW_MANAGER, address(lrtWithdrawalProxy));
        // lrtConfig.setContract(LRTConstants.LRT_UNSTAKING_VAULT, address(lrtUnstakingProxy));
        // lrtConfig.setContract(LRTConstants.EIGEN_DELEGATION_MANAGER, Addresses.EIGEN_DELEGATION_MANAGER);
        // lrtConfig.grantRole(LRTConstants.BURNER_ROLE, address(lrtWithdrawalProxy));

        vm.stopBroadcast();
    }
}
