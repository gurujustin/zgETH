// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4 <0.9.0;

interface IXZerogDeposit {
    function deposit(
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _deadline,
        string calldata _referralId
    )
        external
        returns (uint256);
    function sweep() external payable;

    function updatePrice(uint256 price, uint256 timestamp) external;
    function lastPrice() external view returns(uint256);
}
