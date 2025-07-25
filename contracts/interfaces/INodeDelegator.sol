// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "./IStrategy.sol";
import { IEigenDelegationManager } from "./IEigenDelegationManager.sol";

interface INodeDelegator {
    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event ETHRewardsClaimed(uint256 amount);
    event ETHRewardsWithdrawInitiated(uint256 amount);
    event FeeConfigUpdated(address feeAddress, uint256 feeBasisPoints);
    event ProtocolFeesPaid(uint256 feeAmount, address feeAddress);
    event RewardsDeposited(uint256 amount);
    event ElSharesDelegated(address indexed elOperator);
    event WithdrawalQueued(uint256 nonce, address withdrawer, bytes32 withdrawalRoot);
    event EigenLayerWithdrawalCompleted(address indexed depositor, uint256 nonce, address indexed caller);

    // errors
    error TokenTransferFailed();
    error StrategyIsNotSetForAsset();
    error InvalidETHSender();
    error InvalidRewardAmount();
    error InvalidDepositRoot(bytes32 expectedDepositRoot, bytes32 actualDepositRoot);
    error InvalidZeroInput();
    error OverMaxBasisPoints();
    error TransferFailed();
    error StrategyMustNotBeBeaconChain();
    error MismatchedArrayLengths();

    // getter

    function stakedButNotVerifiedEth() external view returns (uint256);

    // methods
    function depositAssetIntoStrategy(address asset) external;
    function depositAssetsIntoStrategy(address[] calldata assets) external;

    function maxApproveToEigenStrategyManager(address asset) external;
    function initiateUnstaking(IEigenDelegationManager.QueuedWithdrawalParams calldata queuedWithdrawalParam)
        external
        returns (bytes32 withdrawalRoot);

    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256);
    function getETHEigenPodBalance() external view returns (uint256);
    function transferBackToLRTDepositPool(address asset, uint256 amount) external;
    function sendETHFromDepositPoolToNDC() external payable;
}
