// Deployed contract addresses on Sepolia
export const CONTRACTS = {
  PaymentGateway: '0xCD30af277c308C12E6164EF5720dAFC0F7385AD5',
  MerchantRegistry: '0x3FA38C1B92dE06c744784B18DEf8C3088E1C96f1',
  PriceOracle: '0x8E0518C9252227dCAa47492E1691DF83bA436a95',
} as const;

// Token addresses (from deployment script)
export const TOKENS = {
  ETH: '0x1111111111111111111111111111111111111111', // Must match deployment script
  BTC: '0x0000000000000000000000000000000000000001',
  USDC: '0x0000000000000000000000000000000000000002',
} as const;

export const CHAIN_ID = 11155111; // Sepolia