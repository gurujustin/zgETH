// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

import "./XZerogBridgeStorage.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../connext/core/IXReceiver.sol";
import "../connext/core/IWeth.sol";
import "../xerc20/interfaces/IXERC20.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "../../utils/LRTConfigRoleChecker.sol";

contract XZerogBridge is
    IXReceiver,
    Initializable,
    ReentrancyGuardUpgradeable,
    XZerogBridgeStorage,
    LRTConfigRoleChecker
{
    using SafeERC20 for IERC20;

    /// @dev Event emitted when bridge triggers zgETH mint
    event ZgETHMinted(
        bytes32 transferId, uint256 amountDeposited, uint32 origin, address originSender, uint256 zgETHMinted
    );

    /// @dev Event emitted when a message is sent to another chain.
    // The chain selector of the destination chain.
    // The address of the receiver on the destination chain.
    // The exchange rate sent.
    // the token address used to pay CCIP fees.
    // The fees paid for sending the CCIP message.
    event MessageSent( // The unique ID of the CCIP message.
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        uint256 exchangeRate,
        address feeToken,
        uint256 fees
    );

    event ConnextMessageSent( // The chain domain Id of the destination chain.
        // The address of the receiver on the destination chain.
        // The exchange rate sent.
        // The fees paid for sending the Connext message.
    uint32 indexed destinationChainDomain, address receiver, uint256 exchangeRate, uint256 fees);

    /// @dev - This contract expects all tokens to have 18 decimals for pricing
    uint8 public constant EXPECTED_DECIMALS = 18;

    /// @dev - LrtConfig can be set only once;
    bool public isSetLrtConfig = false;

    /// @dev Prevents implementation contract from being initialized.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract with initial vars
    function initialize(
        address _zgETH,
        address _xzgETH,
        address _lrtDepositPool,
        address _wETH,
        address _xzgETHLockbox,
        address _connext,
        address _linkRouterClient,
        address _lrtOracle,
        address _linkToken
    )
        public
        initializer
    {
        // Verify non-zero addresses on inputs
        if (
            _zgETH == address(0) || _xzgETH == address(0) || _lrtDepositPool == address(0) || _wETH == address(0)
                || _xzgETHLockbox == address(0) || _connext == address(0) || _linkRouterClient == address(0)
                || _lrtOracle == address(0) || _linkToken == address(0)
        ) {
            revert InvalidZeroInput();
        }

        // Verify all tokens have 18 decimals
        uint8 decimals = IERC20MetadataUpgradeable(_zgETH).decimals();
        if (decimals != EXPECTED_DECIMALS) {
            revert InvalidTokenDecimals(EXPECTED_DECIMALS, decimals);
        }
        decimals = IERC20MetadataUpgradeable(_xzgETH).decimals();
        if (decimals != EXPECTED_DECIMALS) {
            revert InvalidTokenDecimals(EXPECTED_DECIMALS, decimals);
        }
        decimals = IERC20MetadataUpgradeable(_wETH).decimals();
        if (decimals != EXPECTED_DECIMALS) {
            revert InvalidTokenDecimals(EXPECTED_DECIMALS, decimals);
        }
        decimals = IERC20MetadataUpgradeable(_linkToken).decimals();
        if (decimals != EXPECTED_DECIMALS) {
            revert InvalidTokenDecimals(EXPECTED_DECIMALS, decimals);
        }

        // Save off inputs
        zgETH = IERC20(_zgETH);
        xzgETH = IERC20(_xzgETH);
        lrtDepositPool = ILRTDepositPool(_lrtDepositPool);
        wETH = IERC20(_wETH);
        xzgETHLockbox = IXERC20Lockbox(_xzgETHLockbox);
        connext = IConnext(_connext);
        linkRouterClient = IRouterClient(_linkRouterClient);
        lrtOracle = ILRTOracle(_lrtOracle);
        linkToken = LinkTokenInterface(_linkToken);
    }

    /**
     * @notice  Accepts collateral from the bridge
     * @dev     This function will take all collateral and deposit it into Zerog
     *          The zgETH from the deposit will be sent to the lockbox to be wrapped into xzgETH
     *          The xzgETH will be burned so that the xzgETH on the L2 can be unwrapped for zgETH later
     * @notice  WARNING: This function does NOT whitelist who can send funds from the L2 via Connext.  Users should NOT
     *          send funds directly to this contract.  A user who sends funds directly to this contract will cause
     *          the tokens on the L2 to become over collateralized and will be a "donation" to protocol.  Only use
     *          the deposit contracts on the L2 to send funds to this contract.
     */
    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes memory
    )
        external
        nonReentrant
        returns (bytes memory)
    {
        // Only allow incoming messages from the Connext contract
        if (msg.sender != address(connext)) {
            revert InvalidSender(address(connext), msg.sender);
        }

        // Check that the token received is wETH
        if (_asset != address(wETH)) {
            revert InvalidTokenReceived();
        }

        // Check that the amount sent is greater than 0
        if (_amount == 0) {
            revert InvalidZeroInput();
        }

        // Get the balance of ETH before the withdraw
        uint256 ethBalanceBeforeWithdraw = address(this).balance;

        // Unwrap the WETH
        IWeth(address(wETH)).withdraw(_amount);

        // Get the amount of ETH
        uint256 ethAmount = address(this).balance - ethBalanceBeforeWithdraw;

        // Get the amonut of zgETH before the deposit
        uint256 zgETHBalanceBeforeDeposit = zgETH.balanceOf(address(this));

        // Deposit it into Zerog LRTDepositPool
        lrtDepositPool.depositETH{ value: ethAmount }(0, "Origin");

        // Get the amount of zgETH that was minted
        uint256 zgETHAmount = zgETH.balanceOf(address(this)) - zgETHBalanceBeforeDeposit;

        // Approve the lockbox to spend the zgETH
        zgETH.safeApprove(address(xzgETHLockbox), zgETHAmount);

        // Get the xzgETH balance before the deposit
        uint256 xzgETHBalanceBeforeDeposit = xzgETH.balanceOf(address(this));

        // Send to the lockbox to be wrapped into xzgETH
        xzgETHLockbox.deposit(zgETHAmount);

        // Get the amount of xzgETH that was minted
        uint256 xzgETHAmount = xzgETH.balanceOf(address(this)) - xzgETHBalanceBeforeDeposit;

        // Burn it - it was already minted on the L2
        IXERC20(address(xzgETH)).burn(address(this), xzgETHAmount);

        // Emit the event
        emit ZgETHMinted(_transferId, _amount, _origin, _originSender, zgETHAmount);

        // Return 0 for success
        bytes memory returnData = new bytes(0);
        return returnData;
    }

    /**
     * @notice  Send the price feed to the L1
     * @dev     Calls the zgETHPrice() function to get the current zgETH to ETH price and sends to the L2.
     *          This should be a permissioned call for only OPERATOR_ROLE role
     * @param _destinationParam array of CCIP destination chain param
     * @param _connextDestinationParam array of connext destination chain param
     */
    function sendPrice(
        CCIPDestinationParam[] calldata _destinationParam,
        ConnextDestinationParam[] calldata _connextDestinationParam
    )
        external
        payable
        onlyLRTOperator
        nonReentrant
    {
        // call zgETHPrice() to get the current price of zgETH
        uint256 exchangeRate = lrtOracle.zgETHPrice();
        bytes memory _callData = abi.encode(exchangeRate, block.timestamp);
        // send price feed to zerog CCIP receivers
        for (uint256 i = 0; i < _destinationParam.length;) {
            Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(_destinationParam[i]._zerogReceiver), // ABI-encoded XZerogDepsot contract address
                data: _callData, // ABI-encoded zgETH exchange rate with Timestamp
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit
                    Client.EVMExtraArgsV1({ gasLimit: 200_000 })
                    ),
                // Set the feeToken  address, indicating LINK will be used for fees
                feeToken: address(linkToken)
            });

            // Get the fee required to send the message
            uint256 fees = linkRouterClient.getFee(_destinationParam[i].destinationChainSelector, evm2AnyMessage);

            if (fees > linkToken.balanceOf(address(this))) {
                revert NotEnoughBalance(linkToken.balanceOf(address(this)), fees);
            }

            // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
            linkToken.approve(address(linkRouterClient), fees);

            // Send the message through the router and store the returned message ID
            bytes32 messageId = linkRouterClient.ccipSend(_destinationParam[i].destinationChainSelector, evm2AnyMessage);

            // Emit an event with message details
            emit MessageSent(
                messageId,
                _destinationParam[i].destinationChainSelector,
                _destinationParam[i]._zerogReceiver,
                exchangeRate,
                address(linkToken),
                fees
            );
            unchecked {
                ++i;
            }
        }

        // send price feed to zerog connext receiver
        for (uint256 i = 0; i < _connextDestinationParam.length;) {
            connext.xcall{ value: _connextDestinationParam[i].relayerFee }(
                _connextDestinationParam[i].destinationDomainId,
                _connextDestinationParam[i]._zerogReceiver,
                address(0),
                msg.sender,
                0,
                0,
                _callData
            );

            emit ConnextMessageSent(
                _connextDestinationParam[i].destinationDomainId,
                _connextDestinationParam[i]._zerogReceiver,
                exchangeRate,
                _connextDestinationParam[i].relayerFee
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice  Sweeps accidental ETH value sent to the contract
     * @dev     Restricted to be called by the LRTManager only.
     * @param   _amount  amount of native asset
     * @param   _to  destination address
     */
    function recoverNative(uint256 _amount, address _to) external onlyLRTManager {
        payable(_to).transfer(_amount);
    }

    /**
     * @notice  Sweeps accidental ERC20 value sent to the contract
     * @dev     Restricted to be called by the LRTManager only.
     * @param   _token  address of the ERC20 token
     * @param   _amount  amount of ERC20 token
     * @param   _to  destination address
     */
    function recoverERC20(address _token, uint256 _amount, address _to) external onlyLRTManager {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /**
     * @notice  Set LRTConfig address
     * @param   _lrtConfig  address of the LRTConfig token
     */
    function setLrtConfig(address _lrtConfig) external {
        if (isSetLrtConfig) {
            revert AlreadySet();
        }
        isSetLrtConfig = true;
        lrtConfig = ILRTConfig(_lrtConfig);
    }

    /**
     * @notice Fallback function to handle ETH sent to the contract from unwrapping WETH
     * @dev Warning: users should not send ETH directly to this contract!
     */
    receive() external payable { }
}
