# include .env file and export its env vars
# (-include to ignore error if it does not exist)
# Note that any unset variables here will wipe the variables if they are set in
# .zshrc or .bashrc. Make sure that the variables are set in .env, especially if
# you're running into issues with fork tests
-include .env

# forge coverage

coverage :; forge coverage --report lcov && lcov --remove lcov.info  -o lcov.info 'test/*' 'script/*'

# deployment commands
deploy-lrt-testnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url ${SEPOLIA_RPC_URL}  --broadcast --verify -vvvv
deploy-lrt-holesky :; forge script script/foundry-scripts/DeployLRTHolesky.s.sol:DeployLRTHolesky --rpc-url ${HOLESKY_RPC_URL}  --broadcast --verify -vvvv
deploy-lrt-native-testnet :; forge script script/foundry-scripts/DeployLRTNative.s.sol:DeployLRTNative --rpc-url ${SEPOLIA_RPC_URL}  --broadcast --verify -vvvv
deploy-lrt-native-mainnet :; forge script script/foundry-scripts/DeployLRTNative.s.sol:DeployLRTNative --rpc-url ${MAINNET_RPC_URL}  --broadcast --verify -vvvv
deploy-lrt-native-arbitrum :; forge script script/foundry-scripts/DeployLRTNative.s.sol:DeployLRTNative --rpc-url ${ARBITRUM_RPC_URL} --etherscan-api-key ${ARBISCAN_API_KEY} --broadcast --skip-simulation --verify -vvvv
verify-lrt-native-arbitrum :; forge script script/foundry-scripts/DeployLRTNative.s.sol:DeployLRTNative --rpc-url ${ARBITRUM_RPC_URL} --etherscan-api-key ${ARBISCAN_API_KEY} --verify -vvvv --resume
deploy-lrt-mainnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url ${MAINNET_RPC_URL}  --broadcast --verify -vvvv
deploy-lrt-local-test :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url localhost --broadcast -vvv
deploy-lrt-additional-mainnet :; forge script script/foundry-scripts/DeployWithdrawal.s.sol:DeployWithdrawal --rpc-url ${HOLESKY_RPC_URL}  --broadcast --verify -vvvv
upgrade-lrt-nodedelegator-holesky :; forge script script/foundry-scripts/UpgradeNodeDelegator.s.sol:UpgradeNodeDelegator --rpc-url ${HOLESKY_RPC_URL}  --broadcast --verify -vvvv

# deployment commands: Connext
deploy-connext-origin:; forge script script/foundry-scripts/DeployConnextOrigin.s.sol:DeployConnextOrigin --rpc-url ${MAINNET_RPC_URL}  --broadcast --verify -vvvv
deploy-connext-origin-arbitrum:; forge script script/foundry-scripts/DeployConnextOrigin.s.sol:DeployConnextOrigin --rpc-url ${ARBITRUM_RPC_URL} --etherscan-api-key ${ARBISCAN_API_KEY} --broadcast --skip-simulation --verify -vvvv
deploy-connext-base:; forge script script/foundry-scripts/DeployConnext.s.sol:DeployConnext --rpc-url ${BASE_RPC_URL}  --broadcast --etherscan-api-key ${BASE_ETHERSCAN_API_KEY} --verifier-url ${BASE_VERIFIER_URL} --verify -vvvv
deploy-connext-arbitrum:; forge script script/foundry-scripts/DeployConnext.s.sol:DeployConnext --rpc-url ${ARBITRUM_RPC_URL}  --broadcast --skip-simulation --etherscan-api-key ${ARBISCAN_API_KEY} --verifier-url ${ARBITRUM_VERIFIER_URL} --verify -vvvv
deploy-connext-optimism:; forge script script/foundry-scripts/DeployConnext.s.sol:DeployConnext --rpc-url ${OPTIMISM_RPC_URL}  --broadcast --etherscan-api-key ${OP_ETHERSCAN_API_KEY} --verifier-url ${OPTIMISM_VERIFIER_URL} --verify -vvvv
deploy-connext-mode:; forge script script/foundry-scripts/DeployConnext.s.sol:DeployConnext --rpc-url ${MODE_RPC_URL} --broadcast
deploy-connext-optimism-testnet:; forge script script/foundry-scripts/DeployConnext.s.sol:DeployConnext --rpc-url ${OPTIMISM_SEPOLIA_RPC_URL}  --broadcast --etherscan-api-key ${OP_ETHERSCAN_API_KEY} --verifier-url ${OPTIMISM_SEPOLIA_VERIFIER_URL} --verify -vvvv
verify-connext-optimism-resume:; forge script script/foundry-scripts/DeployConnext.s.sol:DeployConnext --rpc-url ${OPTIMISM_RPC_URL}  --etherscan-api-key ${OP_ETHERSCAN_API_KEY} --verifier-url ${OPTIMISM_VERIFIER_URL} --verify -vvvv --resume

# deployment commands: LayerZero
deploy-layerzero-frax:; forge script script/foundry-scripts/DeployWZgETH_Pool.s.sol:DeployWZgETH_Pool --rpc-url ${FRAX_RPC_URL}  --broadcast --etherscan-api-key ${FRAXSCAN_API_KEY} --verify -vvv

# deployment commands: OneETHPriceOracle
deploy-eth-oracle-testnet :; forge script script/foundry-scripts/DeployOneETHPriceOracle.s.sol:DeployOneETHPriceOracle --rpc-url ${SEPOLIA_RPC_URL}  --broadcast --verify -vvvv
deploy-eth-oracle-mainnet :; forge script script/foundry-scripts/DeployOneETHPriceOracle.s.sol:DeployOneETHPriceOracle --rpc-url ${MAINNET_RPC_URL}  --broadcast --verify -vvvv
deploy-eth-oracle-local-test :; forge script script/foundry-scripts/DeployOneETHPriceOracle.s.sol:DeployOneETHPriceOracle --rpc-url localhost --broadcast -vvv

# upgrade commands: XZerogBridge
upgrade-eth-bridge-testnet :; forge script script/foundry-scripts/UpgradeBridgeOrigin.s.sol:UpgradeBridgeOrigin --rpc-url ${SEPOLIA_RPC_URL}  --broadcast --verify -vvvv
upgrade-eth-bridge-mainnet :; forge script script/foundry-scripts/UpgradeBridgeOrigin.s.sol:UpgradeBridgeOrigin --rpc-url ${MAINNET_RPC_URL}  --broadcast --verify -vvvv


# deployment commands:ZGETHRate
deploy-preth-rate-provider :; forge script script/foundry-scripts/cross-chain/ZGETHRate.s.sol:DeployZGETHRateProvider --rpc-url ${ARBITRUM_RPC_URL}  --broadcast --skip-simulation --etherscan-api-key ${ARBISCAN_API_KEY} --verifier-url ${ARBITRUM_VERIFIER_URL} --verify -vvvv
deploy-preth-rate-receiver :; forge script script/foundry-scripts/cross-chain/ZGETHRate.s.sol:DeployZGETHRateReceiver --rpc-url ${FRAX_RPC_URL}  --broadcast --etherscan-api-key ${FRAXSCAN_API_KEY} --verify -vvv
deploy-preth-rate-local-test :; forge script script/foundry-scripts/cross-chain/ZGETHRate.s.sol:DeployZGETHRateReceiver --rpc-url localhost --broadcast -vvv
verify-preth-arbitrum :; forge verify-contract --chain-id 42161 --watch --verifier-url ${ARBITRUM_VERIFIER_URL} --etherscan-api-key ${ARBISCAN_API_KEY} --constructor-args 000000000000000000000000ae69f9ac9ac9302e2f97b313caf1fb45a9bb18a600000000000000000000000000000000000000000000000000000000000000ff0000000000000000000000003c2269811836af69497e5f486a85d7316753cf620000000000000000000000005c3e80763862cb777aa07bddbcce0123104e1c34 0xf980586D60043D8B8B8A136C8B23e76C5A2C826D contracts/cross-chain/ZGETHRateProvider.sol:ZGETHRateProvider
verify-preth-fraxtal :; forge verify-contract --chain-id 252 --watch --etherscan-api-key ${FRAXSCAN_API_KEY} --constructor-args 000000000000000000000000000000000000000000000000000000000000006e000000000000000000000000f980586d60043d8b8b8a136c8b23e76c5a2c826d000000000000000000000000b6319cc6c8c27a8f5daf0dd3df91ea35c4720dd7 0x73791D65959Eef4827EA6e34Cb5F41312E5c7a31 contracts/cross-chain/ZGETHRateReceiver.sol:ZGETHRateReceiver

# verify commands
## example: contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet
## example: contractAddress=0xE7b647ab9e0F49093926f06E457fa65d56cb456e contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
verify-lrt-proxy-testnet :; forge verify-contract --chain-id 5 --watch --etherscan-api-key ${GOERLI_ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}
verify-lrt-proxy-mainnet :; forge verify-contract --chain-id 1 --watch --etherscan-api-key ${ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}
verify-proxy-arbitrum :; forge verify-contract --chain-id 42161 --watch --verifier-url ${ARBITRUM_VERIFIER_URL} --etherscan-api-key ${ARBISCAN_API_KEY} --constructor-args 000000000000000000000000a89c69c9205a898146fb674225167b47facf8d97000000000000000000000000077e421e26da381e8e0ba70e1633f1b5bc0b0edc00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000 0x5B1f22394f38d7b2C73d076b093eC36CeC6Fb746 TransparentUpgradeableProxy
verify-proxy-frax :; forge verify-contract --chain-id 252 --watch --etherscan-api-key ${FRAXSCAN_API_KEY} --constructor-args 000000000000000000000000c1796A1157C861A0B3F3F80d4242172683EC2C0000000000000000000000000076A06263B9d22D44972C736Aa203aa17B5Cbcf6E00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000 0x14367Ec514De69F88D49b266C2ea1ED058dAf090 script/foundry-scripts/utils/ProxyFactory.sol:ProxyFactory
verify-imp-arbitrum :; forge verify-contract --chain-id 42161 --watch --verifier-url ${ARBITRUM_VERIFIER_URL} --etherscan-api-key ${ARBISCAN_API_KEY} 0xad4fce00e189ab964fd363405e094c06fb2e2b05 LRTDepositPool


# transfer the ownership of the contracts to Multisig
transfer-ownership-arbitrum :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${ARBITRUM_RPC_URL}  --broadcast -vvv
transfer-ownership-optimism :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${OPTIMISM_RPC_URL}  --broadcast -vvv
transfer-ownership-base :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${BASE_RPC_URL}  --broadcast -vvv
transfer-ownership-mainnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${MAINNET_RPC_URL}  --broadcast -vvv
transfer-ownership-fork :; IS_FORK=true forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url localhost --broadcast -vvv

# deploy minimal setup
minimal-deploy-testnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url sepolia  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-mainnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-local-test :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url localhost --broadcast -vvv

# Deploy DeployZgETH
deploy-token-testnet :; forge script script/foundry-scripts/DeployZgETH.s.sol:DeployZgETH --rpc-url sepolia  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-token-mainnet :; forge script script/foundry-scripts/DeployZgETH.s.sol:DeployZgETH --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-token-fork :; IS_FORK=true forge script script/foundry-scripts/DeployZgETH.s.sol:DeployZgETH --rpc-url localhost --broadcast -vvv

# deploy the Assets
add-assets-mainnet :; forge script script/foundry-scripts/AddAssets.s.sol:AddAssets --rpc-url ${MAINNET_RPC_URL}  --broadcast -vvv
add-assets-fork :; IS_FORK=true forge script script/foundry-scripts/AddAssets.s.sol:AddAssets --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast -vvv

# set max depsoits
deposit-limits-mainnet :; forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url ${MAINNET_RPC_URL}  --broadcast
deposit-limits-fork :; IS_FORK=true forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast

# Deploy LRTDepositPool
deploy-deposit-pool-mainnet :; forge script script/foundry-scripts/DeployDepositPool.s.sol:DeployDepositPool --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-deposit-delegator-fork :; IS_FORK=true forge script script/foundry-scripts/DeployDepositPool.s.sol:DeployDepositPool --rpc-url localhost --broadcast -vvv
upgrade-deposit-delegator-local :; forge script script/foundry-scripts/DeployDepositPool.s.sol:DeployDepositPool --rpc-url localhost --broadcast -vvv

# Deploy NodeDelegator
deploy-node-delegator-mainnet :; forge script script/foundry-scripts/DeployNodeDelegator.s.sol:DeployNodeDelegator --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-node-delegator-fork :; IS_FORK=true forge script script/foundry-scripts/DeployNodeDelegator.s.sol:DeployNodeDelegator --rpc-url localhost --broadcast -vvv
upgrade-node-delegator-local :; forge script script/foundry-scripts/NodeDeDeployNodeDelegatorlegator.s.sol:DeployNodeDelegator --rpc-url localhost --broadcast -vvv

# Deploy LRTOracle
deploy-oracle-mainnet :; forge script script/foundry-scripts/DeployOracle.s.sol:DeployOracle --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-oracle-fork :; IS_FORK=true forge script script/foundry-scripts/DeployOracle.s.sol:DeployOracle --rpc-url localhost --broadcast -vvv
upgrade-oracle-local :; forge script script/foundry-scripts/DeployOracle.s.sol:DeployOracle --rpc-url localhost --broadcast -vvv

deploy-oracles-mainnet :; forge script script/foundry-scripts/DeployOracles.s.sol:DeployOracles --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

# Deploy ChainlinkPriceOracle
deploy-chainlink-mainnet :; forge script script/foundry-scripts/DeployChainlinkPriceOracle.s.sol:DeployChainlinkPriceOracle --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-chainlink-fork :; IS_FORK=true forge script script/foundry-scripts/DeployChainlinkPriceOracle.s.sol:DeployChainlinkPriceOracle --rpc-url localhost --broadcast -vvv
upgrade-chainlink-local :; forge script script/foundry-scripts/DeployChainlinkPriceOracle.s.sol:DeployChainlinkPriceOracle --rpc-url localhost --broadcast -vvv

# Started a local forked node
ifneq ($(BLOCK_NUMBER),)
    BLOCK_PARAM=--fork-block-number=${BLOCK_NUMBER}
endif
node-fork:; anvil --fork-url ${MAINNET_RPC_URL} --auto-impersonate ${BLOCK_PARAM}

# test commands
unit-test:; forge test --no-match-contract "(Skip|IntegrationTest|ForkTest)"
int-test:; MAINNET_RPC_URL=localhost forge test --match-contract "IntegrationTest" --no-match-contract "Skip"
fork-test:; forge test --match-contract "ForkTest" --no-match-contract "Skip" -vv
fork-test-ci:; forge test --match-contract "ForkTest" --no-match-contract "Skip"