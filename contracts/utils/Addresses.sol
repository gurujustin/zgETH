// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

library Addresses {
    address public constant ADMIN_MULTISIG = 0xD35E82A5d59d0bEc88cb38058212A81B630c9308;

    address public constant ADMIN_ROLE = ADMIN_MULTISIG;
    address public constant MANAGER_ROLE = ADMIN_MULTISIG;
    address public constant OPERATOR_ROLE = ADMIN_MULTISIG;

    address public constant PROXY_OWNER = ADMIN_MULTISIG;
    address public constant PROXY_FACTORY = 0x948741493164822Df2bC359A394828ef6c112a8F;
    address public constant PROXY_ADMIN = 0x50aa78158D31eC12de90828DacFF33895f3dc541;

    address public constant ZGETH = 0x17fdeB2fbB8089fea8a7BDb847E49ce67cF863df;

    address public constant LRT_CONFIG = 0xa680F9dcF5283261F70e551ACCf59BD2C1cD62A2;
    address public constant LRT_ORACLE = 0xAa6Fd6788fCA604AcFD3FE7e160Fbfcf4F0ef95C;
    address public constant LRT_DEPOSIT_POOL = 0xBcE1eD62786703fc974774A43dFCfeB609AD3329;
    address public constant NODE_DELEGATOR = 0x09F722CbD51F29DC1FA487857C114766FD48195D;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant EIGEN_UNPAUSER = 0x369e6F597e22EaB55fFb173C6d9cD234BD699111;
    address public constant EIGEN_STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;

    address public constant CONNEXT_DIAMOND = 0x8898B472C54c31894e3B9bb83cEA802a5d0e63C6;
    address public constant LINK_ROUTER_CLIENT = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address public constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address public constant BRIDGE = 0x7919A673AD97E52260e86468398F6219E1DB1Ffc;

    address public constant OP_LINK_ROUTER_CLIENT = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address public constant OP_WETH = 0x4200000000000000000000000000000000000006;
    address public constant OP_NEXT_WETH = 0x609aEfb9FB2Ee8f2FDAd5dc48efb8fA4EE0e80fB;
    address public constant OP_CONNEXT_DIAMOND = 0x7380511493DD4c2f1dD75E9CCe5bD52C787D4B51;

    address public constant ZGETHRATERECEIVER = 0x73791D65959Eef4827EA6e34Cb5F41312E5c7a31;
    address public constant EIGEN_DELEGATION_MANAGER = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
}
