// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { BeaconChainProofs } from "./utils/external/BeaconChainProofs.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";
import { IEigenStrategyManager } from "./interfaces/IEigenStrategyManager.sol";
import { IEigenDelegationManager } from "./interfaces/IEigenDelegationManager.sol";
import { IEigenDelayedWithdrawalRouter } from "./interfaces/IEigenDelayedWithdrawalRouter.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IEigenPodManager } from "./interfaces/IEigenPodManager.sol";
import { IEigenPod, IBeaconDeposit } from "./interfaces/IEigenPod.sol";

import { ISSVNetwork, Cluster } from "./interfaces/ISSVNetwork.sol";

/// @title NodeDelegator Contract
/// @notice The contract that handles the depositing of assets into strategies
contract NodeDelegator is INodeDelegator, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable {
    /// @dev The EigenPod is created and owned by this contract
    IEigenPod public eigenPod;
    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    /// call verifyWithdrawalCredentials to verify the validator credentials on EigenLayer
    uint256 public stakedButNotVerifiedEth;

    /// @dev address of eigenlayer operator to which all restaked funds are delegated to
    /// @dev it is only possible to delegate fully to only one operator per NDC contract
    address public elOperatorDelegatedTo;

    /// @dev A base tx gas amount for a transaction to be added for redemption later - in gas units
    uint256 public baseGasAmountSpent;

    /// @dev A mapping to track how much gas was spent by an address
    mapping(address => uint256) public adminGasSpentInWei;

    uint256 internal constant DUST_AMOUNT = 10;

    /// @dev Nominal base gas spent value by admin
    uint256 internal constant NOMINAL_BASE_GAS_SPENT = 50_000;

    uint256 public feeBasisPoints;
    address public feeAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        __Pausable_init();
        __ReentrancyGuard_init();

        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    function createEigenPod() external onlyLRTManager {
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.createPod();
        eigenPod = eigenPodManager.ownerToPod(address(this));

        emit EigenPodCreated(address(eigenPod), address(this));
    }

    /// @notice Delegates shares (accrued by restaking LSTs/native eth) to an EigenLayer operator
    /// @param elOperator The address of the operator to delegate to
    /// @param approverSignatureAndExpiry Verifies the operator approves of this delegation
    /// @param approverSalt A unique single use value tied to an individual signature.
    /// @dev delegationManager.delegateTo will check if the operator is valid, if ndc is already delegated to
    function delegateTo(
        address elOperator,
        IEigenDelegationManager.SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    )
        external
        onlyLRTManager
    {
        elOperatorDelegatedTo = elOperator;
        IEigenDelegationManager elDelegationManager =
            IEigenDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER));
        elDelegationManager.delegateTo(elOperator, approverSignatureAndExpiry, approverSalt);
        emit ElSharesDelegated(elOperator);
    }

    /// @notice Approves the maximum amount of an asset to the eigen strategy manager
    /// @dev only supported assets can be deposited and only called by the LRT manager
    /// @param asset the asset to deposit
    function maxApproveToEigenStrategyManager(address asset)
        external
        override
        onlySupportedAsset(asset)
        onlyLRTManager
    {
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);
        IERC20(asset).approve(eigenlayerStrategyManagerAddress, type(uint256).max);
    }

    /// @notice Deposits an asset lying in this NDC into its strategy
    /// @dev only supported assets can be deposited and only called by the LRT Operator
    /// @param asset the asset to deposit
    function depositAssetIntoStrategy(address asset)
        external
        override
        whenNotPaused
        nonReentrant
        onlySupportedAsset(asset)
        onlyLRTOperator
    {
        _depositAssetIntoStrategy(asset);
    }

    /// @notice Deposits all specified assets lying in this NDC into its strategy
    /// @dev only supported assets can be deposited and only called by the LRT Operator
    /// @param assets List of assets to deposit
    function depositAssetsIntoStrategy(address[] calldata assets)
        external
        override
        whenNotPaused
        nonReentrant
        onlyLRTOperator
    {
        // For each of the specified assets
        for (uint256 i; i < assets.length;) {
            // Check the asset is supported
            if (!lrtConfig.isSupportedAsset(assets[i])) {
                revert ILRTConfig.AssetNotSupported();
            }

            _depositAssetIntoStrategy(assets[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Deposits an asset into its strategy.
    /// The calling function is responsible for ensuring the asset is supported.
    /// @param asset the asset to deposit
    function _depositAssetIntoStrategy(address asset) internal {
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            revert StrategyIsNotSetForAsset();
        }

        IERC20 token = IERC20(asset);
        uint256 balance = token.balanceOf(address(this));

        // EigenLayer does not allow minting zero shares. Error: StrategyBase.deposit: newShares cannot be zero
        // So do not deposit if dust amount
        if (balance <= DUST_AMOUNT) {
            return;
        }

        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);

        emit AssetDepositIntoStrategy(asset, strategy, balance);

        IEigenStrategyManager(eigenlayerStrategyManagerAddress).depositIntoStrategy(IStrategy(strategy), token, balance);
    }

    /// @notice Transfers an asset back to the LRT deposit pool
    /// @dev only supported assets can be transferred and only called by the LRT manager
    /// @param asset the asset to transfer
    /// @param amount the amount to transfer
    function transferBackToLRTDepositPool(
        address asset,
        uint256 amount
    )
        external
        whenNotPaused
        nonReentrant
        onlySupportedAsset(asset)
        onlyLRTManager
    {
        address lrtDepositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);

        bool success;
        if (asset == LRTConstants.ETH_TOKEN) {
            (success,) = payable(lrtDepositPool).call{ value: amount }("");
        } else {
            success = IERC20(asset).transfer(lrtDepositPool, amount);
        }

        if (!success) {
            revert TokenTransferFailed();
        }
    }

    /// @notice Fetches balance of all assets staked in eigen layer through this contract
    /// @return assets the assets that the node delegator has deposited into strategies
    /// @return assetBalances the balances of the assets that the node delegator has deposited into strategies
    function getAssetBalances()
        external
        view
        override
        returns (address[] memory assets, uint256[] memory assetBalances)
    {
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);

        (IStrategy[] memory strategies,) =
            IEigenStrategyManager(eigenlayerStrategyManagerAddress).getDeposits(address(this));

        uint256 strategiesLength = strategies.length;
        assets = new address[](strategiesLength);
        assetBalances = new uint256[](strategiesLength);

        for (uint256 i = 0; i < strategiesLength;) {
            assets[i] = address(IStrategy(strategies[i]).underlyingToken());
            assetBalances[i] = IStrategy(strategies[i]).userUnderlyingView(address(this));
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the balance of an asset that the node delegator has deposited into the strategy
    /// @param asset the asset to get the balance of
    /// @return stakedBalance the balance of the asset
    function getAssetBalance(address asset) external view override returns (uint256) {
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            return 0;
        }

        return IStrategy(strategy).userUnderlyingView(address(this));
    }

    /// @dev Returns the balance of an asset that the node delegator has deposited into its EigenPod strategy
    function getETHEigenPodBalance() external view override returns (uint256 ethStaked) {
        // TODO: Once withdrawals are enabled, allow this to handle pending withdraws and a potential negative share
        // balance in the EigenPodManager ownershares
        ethStaked = stakedButNotVerifiedEth;
        if (address(eigenPod) != address(0)) {
            ethStaked += address(eigenPod).balance;
        }
    }

    /// @notice Stake ETH from NDC into EigenLayer. it calls the stake function in the EigenPodManager
    /// which in turn calls the stake function in the EigenPod
    /// @param pubkey The pubkey of the validator
    /// @param signature The signature of the validator
    /// @param depositDataRoot The deposit data root of the validator
    /// @dev Only LRT Operator should call this function
    /// @dev Exactly 32 ether is allowed, hence it is hardcoded
    function stakeEth(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    )
        external
        whenNotPaused
        onlyLRTOperator
    {
        // Call the stake function in the EigenPodManager
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

        // Increment the staked but not verified ETH
        stakedButNotVerifiedEth += 32 ether;

        emit ETHStaked(pubkey, 32 ether);
    }

    /// @notice Stake ETH from NDC into EigenLayer
    /// @param pubkey The pubkey of the validator
    /// @param signature The signature of the validator
    /// @param depositDataRoot The deposit data root of the validator
    /// @param expectedDepositRoot The expected deposit data root, which is computed offchain
    /// @dev Only LRT Operator should call this function
    /// @dev Exactly 32 ether is allowed, hence it is hardcoded
    /// @dev offchain checks withdraw credentials authenticity
    /// @dev compares expected deposit root with actual deposit root
    function stake32EthValidated(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot,
        bytes32 expectedDepositRoot
    )
        external
        whenNotPaused
        onlyLRTOperator
    {
        IBeaconDeposit depositContract = eigenPod.ethPOS();
        bytes32 actualDepositRoot = depositContract.get_deposit_root();
        if (expectedDepositRoot != actualDepositRoot) {
            revert InvalidDepositRoot(expectedDepositRoot, actualDepositRoot);
        }
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

        // tracks staked but unverified native ETH
        stakedButNotVerifiedEth += 32 ether;

        emit ETHStaked(pubkey, 32 ether);
    }

    /// @dev initiate a delayed withdraw of the ETH before the eigenpod is verified
    /// which will be available to claim after withdrawalDelay blocks
    function initiateWithdrawRewards() external onlyLRTOperator {
        uint256 eigenPodBalance = address(eigenPod).balance;
        eigenPod.withdrawBeforeRestaking();
        emit ETHRewardsWithdrawInitiated(eigenPodBalance);
    }

    /// @dev claims back the withdrawal amount initiated to this nodeDelegator contract
    /// once withdrawal amount is claimable
    function claimRewards(uint256 maxNumberOfDelayedWithdrawalsToClaim) external onlyLRTOperator {
        uint256 balanceBefore = address(this).balance;
        address delayedRouterAddr = eigenPod.delayedWithdrawalRouter();
        IEigenDelayedWithdrawalRouter elDelayedRouter = IEigenDelayedWithdrawalRouter(delayedRouterAddr);
        elDelayedRouter.claimDelayedWithdrawals(address(this), maxNumberOfDelayedWithdrawalsToClaim);
        uint256 balanceAfter = address(this).balance;

        emit ETHRewardsClaimed(balanceAfter - balanceBefore);
    }

    /// @dev Verifies the withdrawal credentials for a withdrawal
    /// This will allow the EigenPodManager to verify the withdrawal credentials and credit the OD with shares
    /// Only manager should call this function
    /// @param oracleBlockNumber The oracle block number of the withdrawal
    /// @param validatorIndex The validator index of the withdrawal
    /// @param proofs The proofs of the withdrawal
    /// @param validatorFields The validator fields of the withdrawal
    function verifyWithdrawalCredentials(
        uint64 oracleBlockNumber,
        uint40 validatorIndex,
        BeaconChainProofs.ValidatorFieldsAndBalanceProofs memory proofs,
        bytes32[] calldata validatorFields
    )
        external
        onlyLRTOperator
    {
        uint256 gasBefore = gasleft();
        eigenPod.verifyWithdrawalCredentials(
            oracleTimestamp, stateRootProof, validatorIndices, withdrawalCredentialProofs, validatorFields
        );

        uint256 gweiToWei = 1e9;
        // Decrement the staked but not verified ETH
        for (uint256 i = 0; i < validatorFields.length;) {
            uint64 validatorCurrentBalanceGwei = BeaconChainProofs.getEffectiveBalanceGwei(validatorFields[i]);
            stakedButNotVerifiedEth -= (validatorCurrentBalanceGwei * gweiToWei);

            unchecked {
                ++i;
            }
        }
        eigenPod.verifyWithdrawalCredentialsAndBalance(oracleBlockNumber, validatorIndex, proofs, validatorFields);

        // update the gas spent for RestakeAdmin
        _recordGas(gasBefore, baseGasAmountSpent);
    }

    /**
     * @notice  Verify many Withdrawals and process them in the EigenPod
     * @dev     For each withdrawal (partial or full), verify it in the EigenPod
     *          Only callable by admin.
     * @param   oracleTimestamp  .
     * @param   stateRootProof  .
     * @param   withdrawalProofs  .
     * @param   validatorFieldsProofs  .
     * @param   validatorFields  .
     * @param   withdrawalFields  .
     */
    function verifyAndProcessWithdrawals(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        BeaconChainProofs.WithdrawalProof[] calldata withdrawalProofs,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields,
        bytes32[][] calldata withdrawalFields
    )
        external
        onlyLRTOperator
    {
        uint256 gasBefore = gasleft();
        eigenPod.verifyAndProcessWithdrawals(
            oracleTimestamp, stateRootProof, withdrawalProofs, validatorFieldsProofs, validatorFields, withdrawalFields
        );
        // update the gas spent for RestakeAdmin
        _recordGas(gasBefore, baseGasAmountSpent);
    }

    /// @dev Queues a withdrawal from the strategies
    /// @param queuedWithdrawalParam Array of queued withdrawals
    function initiateUnstaking(IEigenDelegationManager.QueuedWithdrawalParams calldata queuedWithdrawalParam)
        public
        override
        whenNotPaused
        nonReentrant
        onlyLRTOperator
        returns (bytes32 withdrawalRoot)
    {
        uint256 gasBefore = gasleft();
        address beaconChainETHStrategy = lrtConfig.getContract(LRTConstants.BEACON_CHAIN_ETH_STRATEGY);

        ILRTUnstakingVault lrtUnstakingVault =
            ILRTUnstakingVault(lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT));
        for (uint256 i = 0; i < queuedWithdrawalParam.strategies.length;) {
            if (address(beaconChainETHStrategy) == address(queuedWithdrawalParam.strategies[i])) {
                lrtUnstakingVault.addSharesUnstaking(LRTConstants.ETH_TOKEN, queuedWithdrawalParam.shares[i]);
            } else {
                address token = address(queuedWithdrawalParam.strategies[i].underlyingToken());
                address strategy = lrtConfig.assetStrategy(token);

                if (strategy != address(queuedWithdrawalParam.strategies[i])) {
                    revert StrategyIsNotSetForAsset();
                }
                lrtUnstakingVault.addSharesUnstaking(token, queuedWithdrawalParam.shares[i]);
            }
            unchecked {
                ++i;
            }
        }
        address eigenlayerDelegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IEigenDelegationManager eigenlayerDelegationManager =
            IEigenDelegationManager(eigenlayerDelegationManagerAddress);

        IEigenDelegationManager.QueuedWithdrawalParams[] memory queuedWithdrawalParams =
            new IEigenDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawalParams[0] = queuedWithdrawalParam;
        uint256 nonce = eigenlayerDelegationManager.cumulativeWithdrawalsQueued(address(this));
        bytes32[] memory withdrawalRoots = eigenlayerDelegationManager.queueWithdrawals(queuedWithdrawalParams);
        withdrawalRoot = withdrawalRoots[0];

        emit WithdrawalQueued(nonce, address(this), withdrawalRoot);

        // update the gas spent for RestakeAdmin
        _recordGas(gasBefore, NOMINAL_BASE_GAS_SPENT);
    }

    /// @dev Finalizes Eigenlayer withdrawal to enable processing of queued withdrawals
    /// @param withdrawal Struct containing all data for the withdrawal
    /// @param assets Array specifying the `token` input for each strategy's 'withdraw' function.
    /// @param middlewareTimesIndex Index in the middleware times array for withdrawal eligibility check.
    function completeUnstaking(
        IEigenDelegationManager.Withdrawal calldata withdrawal,
        IERC20[] calldata assets,
        uint256 middlewareTimesIndex
    )
        external
        whenNotPaused
        nonReentrant
        onlyLRTOperator
    {
        uint256 gasBefore = gasleft();
        if (assets.length != withdrawal.strategies.length) revert MismatchedArrayLengths();
        address eigenlayerDelegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        // Finalize withdrawal with Eigenlayer Delegation Manager
        IEigenDelegationManager(eigenlayerDelegationManagerAddress).completeQueuedWithdrawal(
            withdrawal, assets, middlewareTimesIndex, true
        );
        address withdrawer = lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT);
        ILRTUnstakingVault lrtUnstakingVault = ILRTUnstakingVault(withdrawer);
        for (uint256 i = 0; i < assets.length;) {
            lrtUnstakingVault.reduceSharesUnstaking(address(assets[i]), withdrawal.shares[i]);
            if (address(assets[i]) != LRTConstants.ETH_TOKEN) {
                assets[i].transfer(withdrawer, withdrawal.strategies[i].sharesToUnderlyingView(withdrawal.shares[i]));
            }
            unchecked {
                i++;
            }
        }
        emit EigenLayerWithdrawalCompleted(withdrawal.staker, withdrawal.nonce, msg.sender);

        // update the gas spent for RestakeAdmin
        _recordGas(gasBefore, NOMINAL_BASE_GAS_SPENT);
    }

    /// @dev Approves the SSV Network contract to transfer SSV tokens for deposits
    function approveSSV() external onlyLRTManager {
        address SSV_TOKEN_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_TOKEN);
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        IERC20(SSV_TOKEN_ADDRESS).approve(SSV_NETWORK_ADDRESS, type(uint256).max);
    }

    /// @dev Deposits more SSV Tokens to the SSV Network contract which is used to pay the SSV Operators
    function depositSSV(uint64[] memory operatorIds, uint256 amount, Cluster memory cluster) external onlyLRTManager {
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        ISSVNetwork(SSV_NETWORK_ADDRESS).deposit(address(this), operatorIds, amount, cluster);
    }

    /// @dev Registers a new validator in the SSV Cluster
    function registerSsvValidator(
        bytes calldata publicKey,
        uint64[] calldata operatorIds,
        bytes calldata sharesData,
        uint256 amount,
        Cluster calldata cluster
    )
        external
        onlyLRTOperator
        whenNotPaused
    {
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        ISSVNetwork(SSV_NETWORK_ADDRESS).registerValidator(publicKey, operatorIds, sharesData, amount, cluster);
    }

    /// @dev Exit a validator in the SSV Cluster
    function exitSsvValidator(
        bytes calldata publicKey,
        uint64[] calldata operatorIds
    )
        external
        onlyLRTOperator
        whenNotPaused
    {
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        ISSVNetwork(SSV_NETWORK_ADDRESS).exitValidator(publicKey, operatorIds);
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyLRTManager {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused
    function unpause() external onlyLRTAdmin {
        _unpause();
    }

    /// @dev allow NodeDelegator to receive ETH
    function sendETHFromDepositPoolToNDC() external payable override {
        // only allow LRT deposit pool to send ETH to this contract
        address lrtDepositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        if (msg.sender != lrtDepositPool) {
            revert InvalidETHSender();
        }

        emit ETHDepositFromDepositPool(msg.value);
    }

    /// @dev Set fee config
    function setFeeConfig(address _feeAddress, uint256 _feeBasisPoints) external onlyLRTManager {
        // Verify address is set if basis points are non-zero
        if (_feeBasisPoints > 0) {
            if (_feeAddress == address(0x0)) revert InvalidZeroInput();
        }

        // Verify basis points are not over 100%
        if (_feeBasisPoints > 10_000) revert OverMaxBasisPoints();

        feeAddress = _feeAddress;
        feeBasisPoints = _feeBasisPoints;

        emit FeeConfigUpdated(_feeAddress, _feeBasisPoints);
    }

    function setBaseGasAmountSpent(uint256 _baseGasAmountSpent) external onlyLRTManager {
        if (_baseGasAmountSpent == 0) revert InvalidZeroInput();
        emit BaseGasAmountSpentUpdated(baseGasAmountSpent, _baseGasAmountSpent);
        baseGasAmountSpent = _baseGasAmountSpent;
    }

    /**
     * @notice  Adds the amount of gas spent for an account
     * @dev     Tracks for later redemption from rewards coming from the DWR
     * @param   initialGas  .
     */
    function _recordGas(uint256 initialGas, uint256 baseGasAmount) internal {
        uint256 gasSpent = (initialGas - gasleft() + baseGasAmount) * block.basefee;
        adminGasSpentInWei[msg.sender] += gasSpent;
        emit GasSpent(msg.sender, gasSpent);
    }

    /**
     * @notice  Send owed refunds to the admin
     * @dev     .
     * @return  uint256  .
     */
    function _refundGas() internal returns (uint256) {
        uint256 gasRefund = address(this).balance >= adminGasSpentInWei[tx.origin]
            ? adminGasSpentInWei[tx.origin]
            : address(this).balance;
        bool success = payable(tx.origin).send(gasRefund);
        if (!success) revert TransferFailed();

        // reset gas spent by admin
        adminGasSpentInWei[tx.origin] -= gasRefund;

        emit GasRefunded(tx.origin, gasRefund);
        return gasRefund;
    }

    /// @dev allow NodeDelegator to receive ETH rewards
    receive() external payable {
        if (msg.sender != address(eigenPod)) {
            uint256 feeAmount = 0;
            // Take protocol cut of rewards if enabled
            if (feeAddress != address(0x0) && feeBasisPoints > 0) {
                feeAmount = msg.value * feeBasisPoints / 10_000;
                (bool success,) = feeAddress.call{ value: feeAmount }("");
                if (!success) revert TransferFailed();

                emit ProtocolFeesPaid(feeAmount, feeAddress);
            }

            uint256 gasRefunded = 0;
            uint256 remainingAmount = address(this).balance;
            if (adminGasSpentInWei[tx.origin] > 0) {
                gasRefunded = _refundGas();
                // update the remaining amount
                remainingAmount -= gasRefunded;
                // If no funds left, return
                if (remainingAmount == 0) {
                    return;
                }
            }
        }

        // Emit the rewards event
        emit RewardsDeposited(msg.value - feeAmount);
    }
}
