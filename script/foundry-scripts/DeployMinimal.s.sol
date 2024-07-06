// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { ZgETH } from "contracts/ZgETH.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

function getLSTs() view returns (address stETH, address ethx) {
    uint256 chainId = block.chainid;

    if (chainId == 1) {
        // mainnet
        stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        ethx = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    } else if (chainId == 5) {
        // goerli
        stETH = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
        ethx = 0x3338eCd3ab3d3503c55c931d759fA6d78d287236;
    } else {
        revert("Unsupported network");
    }
}

contract DeployMinimal is Script {
    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    ZgETH public ZgETHProxy;

    function setUpByAdmin() private {
        // ----------- callable by admin ----------------

        // add oracle to LRT config
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, deployerAddress);
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
        address lrtConfigImplementation = address(new LRTConfig());
        address zgETHImplementation = address(new ZgETH());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("LRTConfig implementation deployed at: ", lrtConfigImplementation);
        console.log("ZgETH implementation deployed at: ", zgETHImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // deploy proxy contracts and initialize them
        lrtConfigProxy = LRTConfig(proxyFactory.create(address(lrtConfigImplementation), address(proxyAdmin), salt));

        // set up LRTConfig init params
        address predictedZgETHAddress = proxyFactory.computeAddress(zgETHImplementation, address(proxyAdmin), salt);
        console.log("predictedZgETHAddress: ", predictedZgETHAddress);
        // init LRTConfig
        // the initialize config supports only 2 LSTs. we will add the others post deployment
        lrtConfigProxy.initialize(deployerAddress, predictedZgETHAddress);

        ZgETHProxy = ZgETH(proxyFactory.create(address(zgETHImplementation), address(proxyAdmin), salt));
        // init ZgETH
        ZgETHProxy.initialize(address(lrtConfigProxy));

        console.log("LRTConfig proxy deployed at: ", address(lrtConfigProxy));
        console.log("ZgETH proxy deployed at: ", address(ZgETHProxy));

        // setup
        setUpByAdmin();

        vm.stopBroadcast();
    }
}
