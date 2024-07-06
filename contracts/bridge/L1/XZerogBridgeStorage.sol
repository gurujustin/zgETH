// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

import "./IXZerogBridge.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../xerc20/interfaces/IXERC20Lockbox.sol";
import "../connext/core/IConnext.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { ILRTDepositPool } from "../../interfaces/ILRTDepositPool.sol";
import { ILRTOracle } from "../../interfaces/ILRTOracle.sol";
import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

abstract contract XZerogBridgeStorage is IXZerogBridge {
    /// @notice The xzgETH token address
    IERC20 public xzgETH;

    /// @notice The zgETH token address
    IERC20 public zgETH;

    /// @notice The LRPDepositPool contract - deposits into the protocol are restaked here
    ILRTDepositPool public lrtDepositPool;

    /// @notice The wETH token address - will be sent via bridge from L2
    IERC20 public wETH;

    /// @notice The lockbox contract for zgETH - minted zgETH is sent here
    IXERC20Lockbox public xzgETHLockbox;

    /// @notice The address of the main Connext contract
    IConnext public connext;

    /// @notice The address of the LRTOracle Contract
    ILRTOracle public lrtOracle;

    /// @notice The address of the Chainlink CCIPv1.2.0 Router Client
    IRouterClient public linkRouterClient;

    /// @notice The address of Chainlink Token
    LinkTokenInterface public linkToken;
}
