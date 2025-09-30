import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useReadContract } from 'wagmi'
import { parseEther } from 'viem'
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'
import MerchantRegistryABI from '../contracts/MerchantRegistry.json'

export default function MerchantDashboard() {
  const { address, isConnected } = useAccount()
  const [businessName, setBusinessName] = useState('')
  const [email, setEmail] = useState('')
  const [amountUSD, setAmountUSD] = useState('')
  const [selectedToken, setSelectedToken] = useState(TOKENS.ETH)
  const [duration, setDuration] = useState('1800') // 30 minutes default
  const [createdPaymentId, setCreatedPaymentId] = useState<string>('')

  const { writeContract: registerMerchant, isPending: isRegistering } = useWriteContract()
  const { writeContract: createPayment, isPending: isCreating } = useWriteContract()

  // Check if merchant is registered
  const { data: isMerchantActive } = useReadContract({
    address: CONTRACTS.MerchantRegistry as `0x${string}`,
    abi: MerchantRegistryABI,
    functionName: 'isMerchantActive',
    args: [address],
  })

  // Get merchant payments
  const { data: merchantPayments, refetch: refetchPayments } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'getMerchantPayments',
    args: [address],
  })

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!isConnected) return

    try {
      await registerMerchant({
        address: CONTRACTS.MerchantRegistry as `0x${string}`,
        abi: MerchantRegistryABI,
        functionName: 'registerMerchant',
        args: [businessName, email],
      })
      alert('Merchant registration submitted!')
    } catch (error) {
      console.error('Registration error:', error)
      alert('Registration failed')
    }
  }

  const handleCreatePayment = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!isConnected || !isMerchantActive) return

    try {
      // Convert USD to 8 decimals (contract expects amountUSD with 8 decimals)
      const usdAmount = BigInt(Math.floor(parseFloat(amountUSD) * 1e8))
      await createPayment({
        address: CONTRACTS.PaymentGateway as `0x${string}`,
        abi: PaymentGatewayABI,
        functionName: 'createPayment',
        args: [selectedToken, usdAmount, Number(duration)],
      })
      alert('Payment created! Check your payments list.')
      refetchPayments()
    } catch (error) {
      console.error('Create payment error:', error)
      alert('Payment creation failed')
    }
  }

  if (!isConnected) {
    return (
      <div className="dashboard-container">
        <div className="connect-prompt">
          <h2>Connect Your Wallet</h2>
          <p>Please connect your wallet to access the merchant dashboard.</p>
        </div>
      </div>
    )
  }

  if (!isMerchantActive) {
    return (
      <div className="dashboard-container">
        <div className="register-section">
          <h2>Register as Merchant</h2>
          <form onSubmit={handleRegister} className="form">
            <div className="form-group">
              <label>Business Name</label>
              <input
                type="text"
                value={businessName}
                onChange={(e) => setBusinessName(e.target.value)}
                required
                placeholder="Enter your business name"
              />
            </div>
            <div className="form-group">
              <label>Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="your@email.com"
              />
            </div>
            <button type="submit" disabled={isRegistering} className="btn-primary">
              {isRegistering ? 'Registering...' : 'Register as Merchant'}
            </button>
          </form>
        </div>
      </div>
    )
  }

  return (
    <div className="dashboard-container">
      <div className="dashboard-header">
        <h2>Merchant Dashboard</h2>
        <p>Wallet: {address}</p>
      </div>

      <div className="create-payment-section">
        <h3>Create New Payment</h3>
        <form onSubmit={handleCreatePayment} className="form">
          <div className="form-row">
            <div className="form-group">
              <label>Amount (USD)</label>
              <input
                type="number"
                step="0.01"
                value={amountUSD}
                onChange={(e) => setAmountUSD(e.target.value)}
                required
                placeholder="0.00"
              />
            </div>
            <div className="form-group">
              <label>Token</label>
              <select value={selectedToken} onChange={(e) => setSelectedToken(e.target.value)}>
                <option value={TOKENS.ETH}>ETH</option>
                <option value={TOKENS.BTC}>BTC</option>
                <option value={TOKENS.USDC}>USDC</option>
              </select>
            </div>
          </div>
          <div className="form-group">
            <label>Duration (seconds)</label>
            <select value={duration} onChange={(e) => setDuration(e.target.value)}>
              <option value="300">5 minutes</option>
              <option value="1800">30 minutes</option>
              <option value="3600">1 hour</option>
              <option value="86400">24 hours</option>
            </select>
          </div>
          <button type="submit" disabled={isCreating} className="btn-primary">
            {isCreating ? 'Creating...' : 'Create Payment'}
          </button>
        </form>
      </div>

      <div className="payments-section">
        <h3>Your Payments</h3>
        {merchantPayments && (merchantPayments as string[]).length > 0 ? (
          <div className="payments-list">
            {(merchantPayments as string[]).map((paymentId: string) => (
              <PaymentCard key={paymentId} paymentId={paymentId} />
            ))}
          </div>
        ) : (
          <p className="no-payments">No payments yet. Create one above!</p>
        )}
      </div>
    </div>
  )
}

function PaymentCard({ paymentId }: { paymentId: string }) {
  const { data: payment } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'getPayment',
    args: [paymentId],
  })

  if (!payment) return null

  const paymentData = payment as any
  const paymentUrl = `${window.location.origin}/pay/${paymentId}`

  return (
    <div className="payment-card">
      <div className="payment-info">
        <p><strong>Payment ID:</strong> {paymentId.slice(0, 10)}...</p>
        <p><strong>Amount USD:</strong> ${(Number(paymentData.amountUSD) / 1e8).toFixed(2)}</p>
        <p><strong>Status:</strong> {['Pending', 'Completed', 'Failed', 'Expired', 'Refunded'][paymentData.status]}</p>
      </div>
      <div className="payment-actions">
        <button
          onClick={() => {
            navigator.clipboard.writeText(paymentUrl)
            alert('Payment URL copied!')
          }}
          className="btn-secondary"
        >
          Copy Payment Link
        </button>
      </div>
    </div>
  )
}