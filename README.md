# WalletWave Frontend

React frontend for the WalletWave crypto payment gateway.

## Features

- 🔐 Wallet connection with RainbowKit
- 💼 Merchant dashboard for payment management
- 💳 Customer payment interface
- 📊 Real-time payment status tracking
- ⏱️ Countdown timer for payment expiration
- 📱 Responsive design

## Setup

1. Install dependencies:
```bash
npm install
```

2. Get a WalletConnect Project ID:
   - Visit https://cloud.walletconnect.com
   - Create a free account
   - Create a new project
   - Copy the Project ID

3. Update the Project ID in `src/wagmi.ts`:
```typescript
projectId: 'YOUR_PROJECT_ID'
```

## Development

Run the development server:
```bash
npm run dev
```

The app will be available at http://localhost:5173

## Deployed Contracts (Sepolia)

- **PaymentGateway**: `0xfa36b06e660a36329b4424421ec91760aeb6650b`
- **MerchantRegistry**: `0x2b79ee4e893f35794b2ef28a32fb3dc82f63f08d`
- **PriceOracle**: `0xc47478e1b22c60c307f1d3cbf9a3dd226062ebca`

## How to Use

### For Merchants

1. Connect your wallet
2. Register as a merchant (one-time)
3. Create payment requests with:
   - USD amount
   - Token (ETH, BTC, or USDC)
   - Expiration time
4. Share payment link with customers
5. Track payment status in your dashboard

### For Customers

1. Connect your wallet
2. Open payment link shared by merchant
3. Review payment details
4. Complete payment
5. Receive confirmation

## Tech Stack

- React + TypeScript
- Vite
- Wagmi v2
- RainbowKit
- Ethers.js v6
- React Router
- TanStack Query

## Network

Currently deployed on **Sepolia Testnet**. Get test ETH from:
- https://sepoliafaucet.com/
- https://www.alchemy.com/faucets/ethereum-sepolia
