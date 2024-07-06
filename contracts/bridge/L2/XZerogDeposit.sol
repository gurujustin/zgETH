// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

import "./XZerogDepositStorage.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../xerc20/interfaces/IXERC20.sol";
import "../connext/core/IWeth.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @author  Zerog
 * @title   XZerogDeposit Contract
 * @dev     Tokens are sent to this contract via deposit, xzgETH is minted for the user,
 *          and funds are batched and bridged down to the L1 for depositing into the Zerog Protocol.
 *          Any zgETH minted on the L1 will be locked in the lockbox for unwrapping at a later time with xzgETH.
 * @notice  Allows L2 minting of xzgETH tokens in exchange for deposited assets
 */
contract XZerogDeposit is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, XZerogDepositStorage {
    using SafeERC20 for IERC20;

    /// @dev - This contract expects all tokens to have 18 decimals for pricing
    uint8 public constant EXPECTED_DECIMALS = 18;

    // errors
    error InvalidZeroInput();
    error InvalidTokenDecimals(uint8 expected, uint8 actual);
    error InvalidZeroOutput();
    error OraclePriceExpired();
    error InsufficientOutputAmount();
    error InvalidTimestamp(uint256 timestamp);
    error InvalidSender(address expectedSender, address actualSender);
    error InvalidOraclePrice();
    error UnauthorizedBridgeSweeper();

    event PriceUpdated(uint256 price, uint256 timestamp);
    event Deposit(address indexed user, uint256 amountIn, uint256 amountOut, string referralId);
    event BridgeSweeperAddressUpdated(address sweeper, bool allowed);
    event BridgeSwept(uint32 destinationDomain, address destinationTarget, address delegate, uint256 amount);

    /// @dev Prevents implementation contract from being initialized.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice  Initializes the contract with initial vars
     * @dev     All tokens are expected to have 18 decimals
     * @param   _currentPrice  Initializes it with an initial price of zgETH to ETH
     * @param   _xzgETH  L2 zgETH token
     * @param   _depositToken  WETH on L2
     * @param   _collateralToken  nextWETH on L2
     * @param   _connext  Connext contract
     * @param   _ccipReceiver Chainlink CCIP receiver contract
     */
    function initialize(
        uint256 _currentPrice,
        address _xzgETH,
        address _depositToken,
        address _collateralToken,
        address _connext,
        address _ccipReceiver,
        uint32 _bridgeDestinationDomain,
        address _bridgeTargetAddress
    )
        public
        initializer
    {
        // Initialize inherited classes
        __Ownable_init();

        // Verify valid non zero values
        if (
            _currentPrice == 0 || _xzgETH == address(0) || _depositToken == address(0) || _collateralToken == address(0)
                || _connext == address(0) || _ccipReceiver == address(0) || _bridgeDestinationDomain == 0
                || _bridgeTargetAddress == address(0)
        ) {
            revert InvalidZeroInput();
        }

        // Verify all tokens have 18 decimals
        uint8 decimals = IERC20MetadataUpgradeable(_depositToken).decimals();
        if (decimals != EXPECTED_DECIMALS) {
            revert InvalidTokenDecimals(EXPECTED_DECIMALS, decimals);
        }
        decimals = IERC20MetadataUpgradeable(_collateralToken).decimals();
        if (decimals != EXPECTED_DECIMALS) {
            revert InvalidTokenDecimals(EXPECTED_DECIMALS, decimals);
        }
        decimals = IERC20MetadataUpgradeable(_xzgETH).decimals();
        if (decimals != EXPECTED_DECIMALS) {
            revert InvalidTokenDecimals(EXPECTED_DECIMALS, decimals);
        }

        // Initialize the price and timestamp
        lastPrice = _currentPrice;
        lastPriceTimestamp = block.timestamp;

        // Set xzgETH address
        xzgETH = IERC20(_xzgETH);

        // Set the depoist token
        depositToken = IERC20(_depositToken);

        // Set the collateral token
        collateralToken = IERC20(_collateralToken);

        // Set the connext contract
        connext = IConnext(_connext);

        // Set ccipReceiver contract address
        ccipReceiver = _ccipReceiver;
        // Connext router fee is 5 basis points
        bridgeRouterFeeBps = 5;

        // Set the bridge destination domain
        bridgeDestinationDomain = _bridgeDestinationDomain;

        // Set the bridge target address
        bridgeTargetAddress = _bridgeTargetAddress;
    }

    /**
     * @notice  Accepts deposit for the user in the native asset and mints xzgETH
     * @dev     This funcion allows anyone to call and deposit the native asset for xzgETH
     *          The native asset will be wrapped to WETH (if it is supported)
     *          zgETH will be immediately minted based on the current price
     *          Funds will be held until sweep() is called.
     * @param   _minOut  Minimum number of xzgETH to accept to ensure slippage minimums
     * @param   _deadline  latest timestamp to accept this transaction
     * @param   _referralId referral id
     * @return  uint256  Amount of xzgETH minted to calling account
     */
    function depositETH(
        uint256 _minOut,
        uint256 _deadline,
        string calldata _referralId
    )
        external
        payable
        nonReentrant
        returns (uint256)
    {
        if (msg.value == 0) {
            revert InvalidZeroInput();
        }

        // Get the deposit token balance before
        uint256 depositBalanceBefore = depositToken.balanceOf(address(this));

        // Wrap the deposit ETH to WETH
        IWeth(address(depositToken)).deposit{ value: msg.value }();

        // Get the amount of tokens that were wrapped
        uint256 wrappedAmount = depositToken.balanceOf(address(this)) - depositBalanceBefore;

        // Sanity check for 0
        if (wrappedAmount == 0) {
            revert InvalidZeroOutput();
        }

        return _deposit(wrappedAmount, _minOut, _deadline, _referralId);
    }

    /**
     * @notice  Accepts deposit for the user in depositToken and mints xzgETH
     * @dev     This funcion allows anyone to call and deposit collateral for xzgETH
     *          zgETH will be immediately minted based on the current price
     *          Funds will be held until sweep() is called.
     *          User calling this function should first approve the tokens to be pulled via transferFrom
     * @param   _amountIn  Amount of tokens to deposit
     * @param   _minOut  Minimum number of xzgETH to accept to ensure slippage minimums
     * @param   _deadline  latest timestamp to accept this transaction
     * @param   _referralId referral id
     * @return  uint256  Amount of xzgETH minted to calling account
     */
    function deposit(
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _deadline,
        string calldata _referralId
    )
        external
        nonReentrant
        returns (uint256)
    {
        if (_amountIn == 0) {
            revert InvalidZeroInput();
        }

        // Transfer deposit tokens from user to this contract
        depositToken.safeTransferFrom(msg.sender, address(this), _amountIn);

        return _deposit(_amountIn, _minOut, _deadline, _referralId);
    }

    /**
     * @notice  Internal function to trade deposit tokens for nextWETH and mint xzgETH
     * @dev     Deposit Tokens should be available in the contract before calling this function
     * @param   _amountIn  Amount of tokens deposited
     * @param   _minOut  Minimum number of xzgETH to accept to ensure slippage minimums
     * @param   _deadline  latest timestamp to accept this transaction
     * @param   _referralId referral id
     * @return  uint256  Amount of xzgETH minted to calling account
     */
    function _deposit(
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _deadline,
        string calldata _referralId
    )
        internal
        returns (uint256)
    {
        // Trade deposit tokens for nextWETH
        uint256 amountOut = _trade(_amountIn, _deadline);
        if (amountOut == 0) {
            revert InvalidZeroOutput();
        }

        // Verify the price is not stale
        if (block.timestamp > lastPriceTimestamp + 1 days) {
            revert OraclePriceExpired();
        }

        // Calculate the amount of xzgETH to mint - assumes 18 decimals for price and token
        uint256 xzgETHAmount = (1e18 * amountOut) / lastPrice;

        // Check that the user will get the minimum amount of xzgETH
        if (xzgETHAmount < _minOut) {
            revert InsufficientOutputAmount();
        }

        // Verify the deadline has not passed
        if (block.timestamp > _deadline) {
            revert InvalidTimestamp(_deadline);
        }

        // Mint xzgETH to the user
        IXERC20(address(xzgETH)).mint(msg.sender, xzgETHAmount);

        // Emit the event and return amount minted
        emit Deposit(msg.sender, _amountIn, xzgETHAmount, _referralId);
        return xzgETHAmount;
    }

    /**
     * @notice  Updates the price feed
     * @dev     This function will receive the price feed and timestamp from the L1 through CCIPReceiver middleware
     * contract.
     *          It should verify the origin of the call and only allow permissioned source to call.
     * @param   _price The price of zgETH sent via L1.
     * @param   _timestamp The timestamp at which L1 sent the price.
     */
    function updatePrice(uint256 _price, uint256 _timestamp) external override {
        if (msg.sender != ccipReceiver) revert InvalidSender(ccipReceiver, msg.sender);
        _updatePrice(_price, _timestamp);
    }

    /**
     * @notice  Updates the price feed from the Owner account
     * @dev     Sets the last price and timestamp
     * @param   price  price of zgETH to ETH - 18 decimal precision
     */
    function updatePriceByOwner(uint256 price) external onlyOwner {
        return _updatePrice(price, block.timestamp);
    }

    /**
     * @notice  Internal function to update price
     * @dev     Sanity checks input values and updates prices
     * @param   _price  Current price of zgETH to ETH - 18 decimal precision
     * @param   _timestamp  The timestamp of the price update
     */
    function _updatePrice(uint256 _price, uint256 _timestamp) internal {
        // Check for 0
        if (_price == 0) {
            revert InvalidZeroInput();
        }

        // Check for price divergence - more than 10%
        if (
            (_price > lastPrice && (_price - lastPrice) > (lastPrice / 10))
                || (_price < lastPrice && (lastPrice - _price) > (lastPrice / 10))
        ) {
            revert InvalidOraclePrice();
        }

        // Do not allow older price timestamps
        if (_timestamp <= lastPriceTimestamp) {
            revert InvalidTimestamp(_timestamp);
        }

        // Do not allow future timestamps
        if (_timestamp > block.timestamp) {
            revert InvalidTimestamp(_timestamp);
        }

        // Update values and emit event
        lastPrice = _price;
        lastPriceTimestamp = _timestamp;

        emit PriceUpdated(_price, _timestamp);
    }

    /**
     * @notice  Trades deposit asset for nextWETH
     * @dev     Note that min out is not enforced here since the asset will be priced to zgETH by the calling function
     * @param   _amountIn  Amount of deposit tokens to trade for collateral asset
     * @return  _deadline Deadline for the trade to prevent stale requests
     */
    function _trade(uint256 _amountIn, uint256 _deadline) internal returns (uint256) {
        // Approve the deposit asset to the connext contract
        depositToken.safeApprove(address(connext), _amountIn);

        // We will accept any amount of tokens out here... The caller of this function should verify the amount meets
        // minimums
        uint256 minOut = 0;

        // Swap the tokens
        TokenId memory tokenId = connext.getTokenId(address(depositToken));
        bytes32 swapKey = keccak256(abi.encode(tokenId.id, tokenId.domain));
        uint256 amountNextWETH =
            connext.swapExact(swapKey, _amountIn, address(depositToken), address(collateralToken), minOut, _deadline);

        // Subtract the bridge router fee
        if (bridgeRouterFeeBps > 0) {
            uint256 fee = (amountNextWETH * bridgeRouterFeeBps) / 10_000;
            amountNextWETH -= fee;
        }

        return amountNextWETH;
    }

    /**
     * @notice  This function will take the balance of nextWETH in the contract and bridge it down to the L1
     * @dev     The L1 contract will unwrap, deposit in Zerog, and lock up the zgETH in the lockbox on L1
     *          This function should only be callable by permissioned accounts
     *          The caller will estimate and pay the gas for the bridge call
     */
    function sweep() public payable nonReentrant {
        // Verify the caller is whitelisted
        if (!allowedBridgeSweepers[msg.sender]) {
            revert UnauthorizedBridgeSweeper();
        }

        // Get the balance of nextWETH in the contract
        uint256 balance = collateralToken.balanceOf(address(this));

        // If there is no balance, return
        if (balance == 0) {
            revert InvalidZeroOutput();
        }

        // Approve it to the connext contract
        collateralToken.safeApprove(address(connext), balance);

        // Need to send some calldata so it triggers xReceive on the target
        bytes memory bridgeCallData = abi.encode(balance);

        connext.xcall{ value: msg.value }(
            bridgeDestinationDomain,
            bridgeTargetAddress,
            address(collateralToken),
            msg.sender,
            balance,
            0, // Asset is already nextWETH, so no slippage will be incurred
            bridgeCallData
        );

        // Emit the event
        emit BridgeSwept(bridgeDestinationDomain, bridgeTargetAddress, msg.sender, balance);
    }

    /**
     * @notice  Allows the owner to set addresses that are allowed to call the bridge() function
     * @dev     .
     * @param   _sweeper  Address of the proposed sweeping account
     * @param   _allowed  bool to allow or disallow the address
     */
    function setAllowedBridgeSweeper(address _sweeper, bool _allowed) external onlyOwner {
        allowedBridgeSweepers[_sweeper] = _allowed;

        emit BridgeSweeperAddressUpdated(_sweeper, _allowed);
    }

    /**
     * @notice  Sweeps accidental ETH value sent to the contract
     * @dev     Restricted to be called by the Owner only.
     * @param   _amount  amount of native asset
     * @param   _to  destination address
     */
    function recoverNative(uint256 _amount, address _to) external onlyOwner {
        payable(_to).transfer(_amount);
    }

    /**
     * @notice  Sweeps accidental ERC20 value sent to the contract
     * @dev     Restricted to be called by the Owner only.
     * @param   _token  address of the ERC20 token
     * @param   _amount  amount of ERC20 token
     * @param   _to  destination address
     */
    function recoverERC20(address _token, uint256 _amount, address _to) external onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
