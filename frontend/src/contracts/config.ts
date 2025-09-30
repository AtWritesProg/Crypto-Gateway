// Deployed contract addresses on Sepolia
export const CONTRACTS = {
  PaymentGateway: '0xfa36b06e660a36329b4424421ec91760aeb6650b',
  MerchantRegistry: '0x2b79ee4e893f35794b2ef28a32fb3dc82f63f08d',
  PriceOracle: '0xc47478e1b22c60c307f1d3cbf9a3dd226062ebca',
} as const;

// Token addresses (from deployment script)
export const TOKENS = {
  ETH: '0x1111111111111111111111111111111111111111',
  BTC: '0x0000000000000000000000000000000000000001',
  USDC: '0x0000000000000000000000000000000000000002',
} as const;

export const CHAIN_ID = 11155111; // Sepolia