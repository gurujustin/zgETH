// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { ZgETH } from "contracts/ZgETH.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { OneETHPriceOracle } from "contracts/oracles/OneETHPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployLRTNative is Script {
    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    ZgETH public ZgETHProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    LRTOracle public lrtOracleProxy;
    OneETHPriceOracle public oneETHPriceOracleProxy;
    NodeDelegator public nodeDelegatorProxy;
    address[] public nodeDelegatorContracts;

    uint256 public minAmountToDeposit;

    function _getStrategies() private view returns (address strategyManager, address eigenpodManager) {
        uint256 chainId = block.chainid;
        // https://github.com/Layr-Labs/eigenlayer-contracts#deployments
        if (chainId == 1) {
            // mainnet
            strategyManager = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
            eigenpodManager = 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338;
        } else {
            // testnet
            strategyManager = 0x779d1b5315df083e3F9E94cB495983500bA8E907;
            eigenpodManager = 0xa286b84C96aF280a49Fe1F40B9627C2A2827df41;
        }
    }

    function _setUpByAdmin() private {
        // ----------- callable by admin ----------------

        // add zgETH to LRT config
        lrtConfigProxy.setZgETH(address(ZgETHProxy));
        // add oracle to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleProxy));
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));
        // call updateAssetStrategy for each asset in LRTConfig
        (address strategyManager, address eigenpodManager) = _getStrategies();
        lrtConfigProxy.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, strategyManager);
        lrtConfigProxy.setContract(LRTConstants.EIGEN_POD_MANAGER, eigenpodManager);

        // grant MANAGER_ROLE to an address in LRTConfig
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, deployerAddress);
        // grant OPERATOR_ROLE to an address in LRTConfig
        lrtConfigProxy.grantRole(LRTConstants.OPERATOR_ROLE, deployerAddress);
        // add minter role to lrtDepositPool so it mints zgETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        lrtDepositPoolProxy.setMinAmountToDeposit(minAmountToDeposit);
    }

    function _setUpByManager() private {
        // call updatePriceOracleFor for each asset in LRTOracle
        lrtOracleProxy.updatePriceOracleFor(LRTConstants.ETH_TOKEN, address(oneETHPriceOracleProxy));
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked("Zerog-Staked"));
        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        deployerAddress = proxyAdmin.owner();
        minAmountToDeposit = 0.0001 ether;

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Proxy factory deployed at: ", address(proxyFactory));
        console.log("Tentative owner of ProxyAdmin: ", deployerAddress);

        // deploy implementation contracts
        address lrtConfigImplementation = address(new LRTConfig());
        address zgETHImplementation = address(new ZgETH());
        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        address lrtOracleImplementation = address(new LRTOracle());
        address oneETHPriceOracleImplementation = address(new OneETHPriceOracle());
        address nodeDelegatorImplementation = address(new NodeDelegator());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("LRTConfig implementation deployed at: ", lrtConfigImplementation);
        console.log("ZgETH implementation deployed at: ", zgETHImplementation);
        console.log("LRTDepositPool implementation deployed at: ", lrtDepositPoolImplementation);
        console.log("LRTOracle implementation deployed at: ", lrtOracleImplementation);
        console.log("OneETHPriceOracle implementation deployed at: ", oneETHPriceOracleImplementation);
        console.log("NodeDelegator implementation deployed at: ", nodeDelegatorImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // deploy proxy contracts and initialize them
        lrtConfigProxy = LRTConfig(proxyFactory.create(address(lrtConfigImplementation), address(proxyAdmin), salt));

        address predictedZgETHAddress = proxyFactory.computeAddress(zgETHImplementation, address(proxyAdmin), salt);
        console.log("predictedZgETHAddress: ", predictedZgETHAddress);

        lrtConfigProxy.initialize(deployerAddress, predictedZgETHAddress);

        ZgETHProxy = ZgETH(proxyFactory.create(address(zgETHImplementation), address(proxyAdmin), salt));
        // init ZgETH
        ZgETHProxy.initialize(address(lrtConfigProxy));

        lrtDepositPoolProxy = LRTDepositPool(
            payable(proxyFactory.create(address(lrtDepositPoolImplementation), address(proxyAdmin), salt))
        );
        // init LRTDepositPool
        lrtDepositPoolProxy.initialize(address(lrtConfigProxy));

        lrtOracleProxy = LRTOracle(proxyFactory.create(address(lrtOracleImplementation), address(proxyAdmin), salt));
        // init LRTOracle
        lrtOracleProxy.initialize(address(lrtConfigProxy));

        oneETHPriceOracleProxy =
            OneETHPriceOracle(proxyFactory.create(address(oneETHPriceOracleImplementation), address(proxyAdmin), salt));

        nodeDelegatorProxy =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));
        // init NodeDelegator
        nodeDelegatorProxy.initialize(address(lrtConfigProxy));

        console.log("LRTConfig proxy deployed at: ", address(lrtConfigProxy));
        console.log("ZgETH proxy deployed at: ", address(ZgETHProxy));
        console.log("LRTDepositPool proxy deployed at: ", address(lrtDepositPoolProxy));
        console.log("LRTOracle proxy deployed at: ", address(lrtOracleProxy));
        console.log("OneETHPriceOracle proxy deployed at: ", address(oneETHPriceOracleProxy));
        console.log("NodeDelegator proxy deployed at: ", address(nodeDelegatorProxy));

        // setup
        _setUpByAdmin();
        _setUpByManager();

        // update zgETHPrice
        lrtOracleProxy.updateZgETHPrice();

        // // We will transfer the ownership once all of the deploys are done
        // uint256 chainId = block.chainid;
        // address manager;
        // address admin;

        // if (chainId == 1) {
        //     // mainnet
        //     manager = 0xEc574b7faCEE6932014EbfB1508538f6015DCBb0;
        //     admin = 0xEc574b7faCEE6932014EbfB1508538f6015DCBb0;
        // } else if (chainId == 5) {
        //     // goerli
        //     manager = deployerAddress;
        //     admin = deployerAddress;
        // } else {
        //     revert("Unsupported network");
        // }

        // lrtConfigProxy.grantRole(LRTConstants.MANAGER, manager);
        // console.log("Manager permission granted to: ", manager);

        // lrtConfigProxy.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin);
        // lrtConfigProxy.revokeRole(LRTConstants.DEFAULT_ADMIN_ROLE, deployerAddress);
        // proxyAdmin.transferOwnership(admin);

        // console.log("ProxyAdmin ownership transferred to: ", admin);

        vm.stopBroadcast();
    }
}
