// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

library LRTConstants {
    bytes32 public constant BEACON_CHAIN_ETH_STRATEGY = keccak256("BEACON_CHAIN_ETH_STRATEGY");

    //contracts
    bytes32 public constant LRT_ORACLE = keccak256("LRT_ORACLE");
    bytes32 public constant LRT_DEPOSIT_POOL = keccak256("LRT_DEPOSIT_POOL");
    bytes32 public constant LRT_WITHDRAW_MANAGER = keccak256("LRT_WITHDRAW_MANAGER");
    bytes32 public constant LRT_UNSTAKING_VAULT = keccak256("LRT_UNSTAKING_VAULT");
    bytes32 public constant EIGEN_STRATEGY_MANAGER = keccak256("EIGEN_STRATEGY_MANAGER");

    // SSV
    bytes32 public constant SSV_TOKEN = keccak256("SSV_TOKEN");
    bytes32 public constant SSV_NETWORK = keccak256("SSV_NETWORK");

    //Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // updated library variables
    bytes32 public constant SFRXETH_TOKEN = keccak256("SFRXETH_TOKEN");
    // add new vars below
    bytes32 public constant EIGEN_POD_MANAGER = keccak256("EIGEN_POD_MANAGER");

    // native ETH as ERC20 for ease of implementation
    address public constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Operator Role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // EigenLayer Delegation Manager
    bytes32 public constant EIGEN_DELEGATION_MANAGER = keccak256("EIGEN_DELEGATION_MANAGER");
}
