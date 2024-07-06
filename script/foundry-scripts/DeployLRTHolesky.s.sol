// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { ZgETH } from "contracts/ZgETH.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { OneETHPriceOracle } from "contracts/oracles/OneETHPriceOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

function getLSTs() view returns (address stETH) {
    uint256 chainId = block.chainid;

    if (chainId == 17_000) {
        // holesky
        stETH = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    } else {
        revert("Unsupported network");
    }
}

contract DeployLRTHolesky is Script {
    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    ZgETH public ZgETHProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    LRTOracle public lrtOracleProxy;
    ChainlinkPriceOracle public chainlinkPriceOracleProxy;
    OneETHPriceOracle public oneETHPriceOracleProxy;
    NodeDelegator public nodeDelegatorProxy1;
    address[] public nodeDelegatorContracts;

    uint256 public minAmountToDeposit;

    function maxApproveToEigenStrategyManager(address nodeDel) private {
        (address stETH) = getLSTs();
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(stETH);
    }

    function getAssetStrategies()
        private
        view
        returns (address strategyManager, address stETHStrategy, address eigenpodManager)
    {
        uint256 chainId = block.chainid;
        // https://github.com/Layr-Labs/eigenlayer-contracts#deployments
        if (chainId == 1) {
            // mainnet
            strategyManager = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
            stETHStrategy = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
            eigenpodManager = 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338;
        } else {
            // testnet
            strategyManager = 0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6;
            stETHStrategy = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3;
            eigenpodManager = 0x30770d7E3e71112d7A6b7259542D1f680a70e315;
        }
    }

    function getPriceFeeds() private returns (address stETHPriceFeed) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // mainnet
            stETHPriceFeed = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;
        } else {
            // testnet
            stETHPriceFeed = address(new MockPriceAggregator());
        }
    }

    function setUpByAdmin() private {
        (address stETH) = getLSTs();
        // ----------- callable by admin ----------------

        // add zgETH to LRT config
        lrtConfigProxy.setZgETH(address(ZgETHProxy));
        // add oracle to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleProxy));
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));
        // call updateAssetStrategy for each asset in LRTConfig
        (address strategyManager, address stETHStrategy, address eigenpodManager) = getAssetStrategies();
        lrtConfigProxy.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, strategyManager);
        lrtConfigProxy.setContract(LRTConstants.EIGEN_POD_MANAGER, eigenpodManager);

        // grant MANAGER_ROLE to an address in LRTConfig
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, deployerAddress);
        // grant OPERATOR_ROLE to an address in LRTConfig
        lrtConfigProxy.grantRole(LRTConstants.OPERATOR_ROLE, deployerAddress);
        // add minter role to lrtDepositPool so it mints zgETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));

        lrtConfigProxy.addNewSupportedAsset(stETH, 100_000 ether);
        lrtConfigProxy.updateAssetStrategy(stETH, stETHStrategy);

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy1));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        lrtDepositPoolProxy.setMinAmountToDeposit(minAmountToDeposit);
    }

    function setUpByManager() private {
        (address stETH) = getLSTs();
        // --------- callable by manager -----------

        (address stETHPriceFeed) = getPriceFeeds();

        // Add chainlink oracles for supported assets in ChainlinkPriceOracle
        chainlinkPriceOracleProxy.updatePriceFeedFor(stETH, stETHPriceFeed);

        // call updatePriceOracleFor for each asset in LRTOracle
        lrtOracleProxy.updatePriceOracleFor(address(stETH), address(chainlinkPriceOracleProxy));
        lrtOracleProxy.updatePriceOracleFor(LRTConstants.ETH_TOKEN, address(oneETHPriceOracleProxy));

        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy1));
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
        address chainlinkPriceOracleImplementation = address(new ChainlinkPriceOracle());
        address oneETHPriceOracleImplementation = address(new OneETHPriceOracle());
        address nodeDelegatorImplementation = address(new NodeDelegator());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("LRTConfig implementation deployed at: ", lrtConfigImplementation);
        console.log("ZgETH implementation deployed at: ", zgETHImplementation);
        console.log("LRTDepositPool implementation deployed at: ", lrtDepositPoolImplementation);
        console.log("LRTOracle implementation deployed at: ", lrtOracleImplementation);
        console.log("ChainlinkPriceOracle implementation deployed at: ", chainlinkPriceOracleImplementation);
        console.log("EthXPriceOracle implementation deployed at: ", oneETHPriceOracleImplementation);
        console.log("NodeDelegator implementation deployed at: ", nodeDelegatorImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // deploy proxy contracts and initialize them
        lrtConfigProxy = LRTConfig(proxyFactory.create(address(lrtConfigImplementation), address(proxyAdmin), salt));

        address predictedZgETHAddress = proxyFactory.computeAddress(zgETHImplementation, address(proxyAdmin), salt);
        console.log("predictedZgETHAddress: ", predictedZgETHAddress);
        // init LRTConfig
        // TODO: the initialize config supports only 2 LSTs. we need to alter this to
        // the number of LSTS we are planning to launch with
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

        chainlinkPriceOracleProxy = ChainlinkPriceOracle(
            proxyFactory.create(address(chainlinkPriceOracleImplementation), address(proxyAdmin), salt)
        );
        // init ChainlinkPriceOracle
        chainlinkPriceOracleProxy.initialize(address(lrtConfigProxy));

        oneETHPriceOracleProxy =
            OneETHPriceOracle(proxyFactory.create(address(oneETHPriceOracleImplementation), address(proxyAdmin), salt));

        nodeDelegatorProxy1 =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));
        // init NodeDelegator
        nodeDelegatorProxy1.initialize(address(lrtConfigProxy));

        console.log("LRTConfig proxy deployed at: ", address(lrtConfigProxy));
        console.log("ZgETH proxy deployed at: ", address(ZgETHProxy));
        console.log("LRTDepositPool proxy deployed at: ", address(lrtDepositPoolProxy));
        console.log("LRTOracle proxy deployed at: ", address(lrtOracleProxy));
        console.log("ChainlinkPriceOracle proxy deployed at: ", address(chainlinkPriceOracleProxy));
        console.log("oneETHPriceOracleProxy proxy deployed at: ", address(oneETHPriceOracleProxy));
        console.log("NodeDelegator proxy 1 deployed at: ", address(nodeDelegatorProxy1));

        // setup
        setUpByAdmin();
        setUpByManager();

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
