// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

interface IXZerogBridge {
    /**
     * @notice Contains destination data for CCIP call
     *
     * @param destinationChainSelector chainlink CCIP destination chain selector ID
     * @param _zerogReceiver XZerogDeposit receiver contract
     */
    struct CCIPDestinationParam {
        uint64 destinationChainSelector;
        address _zerogReceiver;
    }

    /**
     * @notice Contains destination data for Connext xCall
     *
     * @param destinationChainSelector chainlink Connext destination chain domain ID
     * @param _zerogReceiver XZerogDeposit receiver contract
     * @param relayerFee relayer Fee required for xCall
     */
    struct ConnextDestinationParam {
        uint32 destinationDomainId;
        address _zerogReceiver;
        uint256 relayerFee;
    }

    function sendPrice(
        CCIPDestinationParam[] calldata _destinationParam,
        ConnextDestinationParam[] calldata _connextDestinationParam
    )
        external
        payable;

    // errors
    error InvalidZeroInput();
    error InvalidTokenDecimals(uint8 expected, uint8 actual);
    error InvalidSender(address expectedSender, address actualSender);
    error InvalidTokenReceived();
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error AlreadySet();
}
