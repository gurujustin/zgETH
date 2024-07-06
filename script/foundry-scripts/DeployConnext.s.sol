// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

import { XERC20 } from "contracts/bridge/xerc20/XERC20.sol";
import { XERC20Factory } from "contracts/bridge/xerc20/XERC20Factory.sol";
import { XERC20Lockbox } from "contracts/bridge/xerc20/XERC20Lockbox.sol";
import { XZerogDeposit } from "contracts/bridge/L2/XZerogDeposit.sol";
import { Receiver } from "contracts/bridge/L2/ccip/CCIPReceiver.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract DeployConnext is Script {
    ProxyAdmin public proxyAdmin;
    ProxyFactory public proxyFactory;

    XERC20 public xERC20;
    XERC20Lockbox public xERC20Lockbox;
    XERC20Factory public xERC20Factory;
    XZerogDeposit public xZerogDeposit;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked("Zerog-Staked"));

        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin();

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
        _bridges[0] = address(Addresses.OP_CONNEXT_DIAMOND);
        uint256[] memory _burnLimits = new uint256[](1);
        _burnLimits[0] = 1_000_000_000_000_000_000_000;
        uint256[] memory _mintLimits = new uint256[](1);
        _mintLimits[0] = 1_000_000_000_000_000_000_000;
        address _xerc20 = xERC20Factory.deployXERC20(
            "Zerog Staked ETH", "zgETH", _burnLimits, _mintLimits, _bridges, address(proxyAdmin)
        );

        address receiver = address(
            new Receiver(
                Addresses.OP_LINK_ROUTER_CLIENT, // Router address (chainlink)
                Addresses.BRIDGE, // bridge address on L1
                5_009_297_550_715_157_269 // L1 chain selector (chainlink) mainnet
            )
        );

        address xZerogDepositImp = address(new XZerogDeposit());
        xZerogDeposit =
            XZerogDeposit(payable(proxyFactory.create(address(xZerogDepositImp), address(proxyAdmin), salt)));
        xZerogDeposit.initialize(
            1_000_000_000_000_000_000, // current price
            _xerc20,
            Addresses.OP_WETH,
            Addresses.OP_NEXT_WETH,
            Addresses.OP_CONNEXT_DIAMOND,
            receiver,
            6_648_936, // Ethereum Domain
            Addresses.BRIDGE
        );

        Receiver(receiver).setZerogDeposit(address(xZerogDeposit));
        Receiver(receiver).unPause();
        XERC20(_xerc20).setLimits(address(xZerogDeposit), 2_000_000_000_000_000_000_000, 0);

        vm.stopBroadcast();
    }
}
