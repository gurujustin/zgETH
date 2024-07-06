// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTUnstakingVault {
    error CallerNotLRTNodeDelegator();
    error EthTransferFailed();
    error CallerNotLRTWithdrawalManager();

    event EthReceived(address sender, uint256 amount);

    function sharesUnstaking(address asset) external view returns (uint256);

    function getAssetsUnstaking(address asset) external view returns (uint256);

    function balanceOf(address asset) external view returns (uint256);

    function addSharesUnstaking(address asset, uint256 amount) external;

    function reduceSharesUnstaking(address asset, uint256 amount) external;

    function redeem(address asset, uint256 amount) external;
}