// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ZgETHTokenWrapper } from "contracts/cross-chain/ZgETHTokenWrapper.sol";
import { LZZerogDeposit } from "contracts/cross-chain/LZZerogDeposit.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract DeployWZgETH_Pool is Script {
    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    ZgETHTokenWrapper public WZgETHProxy;
    LZZerogDeposit public lzZerogDepositProxy;

    function _setUpByAdmin() private {
        // ----------- callable by admin ----------------
        WZgETHProxy.grantRole(keccak256("MINTER_ROLE"), address(lzZerogDepositProxy));
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked("Zerog-Staked"));
        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        deployerAddress = proxyAdmin.owner();

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Proxy factory deployed at: ", address(proxyFactory));
        console.log("Tentative owner of ProxyAdmin: ", deployerAddress);

        // deploy implementation contracts
        address wzgETHImplementation = address(new ZgETHTokenWrapper());
        address lzZerogDepositImplementation = address(new LZZerogDeposit());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("ZgETHTokenWrapper implementation deployed at: ", wzgETHImplementation);
        console.log("LZZerogDeposit implementation deployed at: ", lzZerogDepositImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // deploy proxy contracts and initialize them

        WZgETHProxy = ZgETHTokenWrapper(proxyFactory.create(address(wzgETHImplementation), address(proxyAdmin), salt));
        // init ZgETHTokenWrapper
        WZgETHProxy.initialize(address(deployerAddress), address(deployerAddress), address(deployerAddress));

        lzZerogDepositProxy = LZZerogDeposit(
            payable(proxyFactory.create(address(lzZerogDepositImplementation), address(proxyAdmin), salt))
        );
        // init LZZerogDeposit
        lzZerogDepositProxy.initialize(
            address(deployerAddress), address(deployerAddress), address(WZgETHProxy), 0, Addresses.ZGETHRATERECEIVER
        );

        console.log("ZgETHTokenWrapper proxy deployed at: ", address(WZgETHProxy));
        console.log("LZZerogDeposit proxy deployed at: ", address(lzZerogDepositProxy));

        _setUpByAdmin();

        vm.stopBroadcast();
    }
}
