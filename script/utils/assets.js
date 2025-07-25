const { ethers } = require("ethers");

const addresses = require("./addresses");
const { ethereumAddress } = require("./regex");

const { abi: ecr20Abi } = require("../../out/IERC20Metadata.sol/IERC20Metadata.json");

const log = require("../utils/logger")("utils:assets");

/**
 * Resolves a token symbol to a ERC20 token contract.
 * @param {string} symbol token symbol of the asset. eg OUSD, USDT, stETH, CRV...
 */
const resolveAddress = (symbol) => {
  const assetAddr = addresses.mainnet[symbol] || addresses.mainnet[symbol + "Proxy"] || symbol;
  if (!assetAddr) {
    throw Error(`Failed to resolve symbol "${symbol}" to an address`);
  }
  log(`Resolved ${symbol} to ${assetAddr}`);
  return assetAddr;
};

/**
 * Resolves a token symbol to a ERC20 token contract.
 * @param {string} symbol token symbol of the asset. eg OUSD, USDT, stETH, CRV...
 */
const resolveAsset = async (symbol, signer) => {
  const assetAddr = addresses.mainnet[symbol] || addresses.mainnet[symbol + "Proxy"] || symbol;
  if (!assetAddr) {
    throw Error(`Failed to resolve symbol "${symbol}" to an address`);
  }
  if (!symbol.match(ethereumAddress)) {
    log(`Resolved ${symbol} to ${assetAddr}`);
  }
  
  const asset = new ethers.Contract(assetAddr, ecr20Abi, signer);

  if (symbol.match(ethereumAddress)) {
    log(`Resolved ${symbol} to ${await asset.symbol()} asset`);
  }
  return asset;
};

module.exports = {
  resolveAddress,
  resolveAsset,
};
