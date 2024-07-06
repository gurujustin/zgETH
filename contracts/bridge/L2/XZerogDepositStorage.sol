// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

import "./IXZerogDeposit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../connext/core/IConnext.sol";

abstract contract XZerogDepositStorage is IXZerogDeposit {
    /// @notice The last timestamp the price was updated
    uint256 public lastPriceTimestamp;

    /// @notice The last price that was updated - denominated in ETH with 18 decimal precision
    uint256 public lastPrice;

    /// @notice The xzgETH token address
    IERC20 public xzgETH;

    /// @notice The deposit token address - this is what users will deposit to mint xzgETH
    IERC20 public depositToken;

    /// @notice The collateral token address - this is what the deposit token will be swapped into and bridged to L1
    IERC20 public collateralToken;

    /// @notice The address of the main Connext contract
    IConnext public connext;

    /// @notice The ccipReceiver middleware contract address
    address public ccipReceiver;
    /// @notice The bridge router fee basis points - 100 basis points = 1%
    uint256 public bridgeRouterFeeBps;

    /// @notice The bridge destination domain - mainnet ETH connext domain
    uint32 public bridgeDestinationDomain;

    /// @notice The contract address where the bridge call should be sent on mainnet ETH
    address public bridgeTargetAddress;

    /// @notice The mapping of allowed addresses that can trigger the bridge function
    mapping(address => bool) public allowedBridgeSweepers;
}
