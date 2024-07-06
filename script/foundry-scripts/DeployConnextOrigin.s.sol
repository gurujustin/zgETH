// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

import { XERC20 } from "contracts/bridge/xerc20/XERC20.sol";
import { XERC20Factory } from "contracts/bridge/xerc20/XERC20Factory.sol";
import { XERC20Lockbox } from "contracts/bridge/xerc20/XERC20Lockbox.sol";
import { XZerogBridge } from "contracts/bridge/L1/XZerogBridge.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract DeployConnextOrigin is Script {
    ProxyAdmin public proxyAdmin;
    ProxyFactory public proxyFactory;

    XERC20 public xERC20;
    XERC20Lockbox public xERC20Lockbox;
    XERC20Factory public xERC20Factory;
    XZerogBridge public xZerogBridge;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked("Zerog-Staked"));

        proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);

        // Deploy the new contract
        address xERC20Impl = address(new XERC20());
        address xERC20LockboxImpl = address(new XERC20Lockbox());
        address xERC20FactoryImpl = address(new XERC20Factory());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("XERC20 implementation deployed at: ", xERC20Impl);
        console.log("XERC20Lockbox implementation deployed at: ", xERC20LockboxImpl);
        console.log("XERC20Factory implementation deployed at: ", xERC20FactoryImpl);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        xERC20Factory = XERC20Factory(proxyFactory.create(address(xERC20FactoryImpl), address(proxyAdmin), salt));
        xERC20Factory.initialize(address(xERC20LockboxImpl), address(xERC20Impl));

        address[] memory _bridges = new address[](1);
        _bridges[0] = address(Addresses.CONNEXT_DIAMOND);
        uint256[] memory _burnLimits = new uint256[](1);
        _burnLimits[0] = 1_000_000_000_000_000_000_000;
        uint256[] memory _mintLimits = new uint256[](1);
        _mintLimits[0] = 1_000_000_000_000_000_000_000;
        address _xerc20 = xERC20Factory.deployXERC20(
            "Zerog Staked ETH", "zgETH", _burnLimits, _mintLimits, _bridges, address(proxyAdmin)
        );
        address _xerc20Lockbox = xERC20Factory.deployLockbox(_xerc20, Addresses.ZGETH, false, address(proxyAdmin));

        address xZerogBridgeImp = address(new XZerogBridge());
        xZerogBridge = XZerogBridge(payable(proxyFactory.create(address(xZerogBridgeImp), address(proxyAdmin), salt)));
        xZerogBridge.initialize(
            Addresses.ZGETH,
            _xerc20,
            Addresses.LRT_DEPOSIT_POOL,
            Addresses.WETH,
            _xerc20Lockbox,
            Addresses.CONNEXT_DIAMOND,
            Addresses.LINK_ROUTER_CLIENT,
            Addresses.LRT_ORACLE,
            Addresses.LINK_TOKEN
        );
        XERC20(_xerc20).setLimits(address(xZerogBridge), 0, 2_000_000_000_000_000_000_000);

        vm.stopBroadcast();
    }
}
