import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'
import MerchantRegistryABI from '../contracts/MerchantRegistry.json'

export default function MerchantDashboard() {
  const { address, isConnected } = useAccount()
  const [businessName, setBusinessName] = useState('')
  const [email, setEmail] = useState('')
  const [amountUSD, setAmountUSD] = useState('')
  const [selectedToken, setSelectedToken] = useState<string>(TOKENS.ETH)
  const [duration, setDuration] = useState('1800') // 30 minutes default
  const [showRegistration, setShowRegistration] = useState(false)

  const { writeContract: registerMerchant, isPending: isRegistering, data: registerHash } = useWriteContract()
  const { writeContract: createPayment, isPending: isCreating, data: createPaymentHash } = useWriteContract()

  // Wait for registration transaction
  const { isSuccess: isRegisterSuccess } = useWaitForTransactionReceipt({
    hash: registerHash,
  })

  // Wait for create payment transaction
  const { isSuccess: isCreatePaymentSuccess } = useWaitForTransactionReceipt({
    hash: createPaymentHash,
  })

  // Check if merchant is registered
  const { data: isMerchantActive, refetch: refetchMerchantStatus } = useReadContract({
    address: CONTRACTS.MerchantRegistry as `0x${string}`,
    abi: MerchantRegistryABI,
    functionName: 'isMerchantActive',
    args: [address],
  })

  // Auto-refetch merchant status after successful registration
  useEffect(() => {
    if (isRegisterSuccess) {
      refetchMerchantStatus()
      setShowRegistration(false)
    }
  }, [isRegisterSuccess, refetchMerchantStatus])

  // Auto-refetch payments after successful payment creation
  useEffect(() => {
    if (isCreatePaymentSuccess) {
      // Small delay to ensure blockchain state has propagated
      setTimeout(() => {
        refetchPayments()
        alert('Payment link created! Check your requests below.')
      }, 1000)
    }
  }, [isCreatePaymentSuccess, refetchPayments])

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
    if (!isConnected) return

    // If not registered, show registration form first
    if (!isMerchantActive) {
      setShowRegistration(true)
      return
    }

    try {
      // Convert USD to 8 decimals (contract expects amountUSD with 8 decimals)
      const usdAmount = BigInt(Math.floor(parseFloat(amountUSD) * 1e8))
      await createPayment({
        address: CONTRACTS.PaymentGateway as `0x${string}`,
        abi: PaymentGatewayABI,
        functionName: 'createPayment',
        args: [selectedToken, usdAmount, Number(duration)],
      })
      // Clear form
      setAmountUSD('')
      // Success alert and refetch will happen in useEffect after transaction confirmation
    } catch (error) {
      console.error('Create payment error:', error)
      alert('Payment creation failed')
    }
  }

  if (!isConnected) {
    return (
      <div className="dashboard-container">
        <div className="connect-prompt">
          <h2>Welcome to WalletWave</h2>
          <p>Connect your wallet to start requesting payments</p>
          <p className="subtitle">Works like PayTM/GPay - Request money with crypto!</p>
        </div>
      </div>
    )
  }

  // Show registration modal when needed
  if (showRegistration && !isMerchantActive) {
    return (
      <div className="dashboard-container">
        <div className="register-section">
          <h2>Quick Setup - Almost There!</h2>
          <p>Before creating your first payment request, we need a few details:</p>
          <form onSubmit={handleRegister} className="form">
            <div className="form-group">
              <label>Your Name / Business Name</label>
              <input
                type="text"
                value={businessName}
                onChange={(e) => setBusinessName(e.target.value)}
                required
                placeholder="John Doe or Your Business"
              />
            </div>
            <div className="form-group">
              <label>Email (for notifications)</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="your@email.com"
              />
            </div>
            <div className="form-actions">
              <button type="button" onClick={() => setShowRegistration(false)} className="btn-secondary">
                Cancel
              </button>
              <button type="submit" disabled={isRegistering} className="btn-primary">
                {isRegistering ? 'Setting up...' : 'Complete Setup'}
              </button>
            </div>
          </form>
        </div>
      </div>
    )
  }

  return (
    <div className="dashboard-container">
      <div className="dashboard-header">
        <h2>Request Money</h2>
        <p className="wallet-info">Your Wallet: {address?.slice(0, 6)}...{address?.slice(-4)}</p>
      </div>

      <div className="create-payment-section">
        <h3>Create Payment Request</h3>
        <form onSubmit={handleCreatePayment} className="form">
          <div className="form-group amount-group">
            <label>How much do you want to receive?</label>
            <div className="amount-input-wrapper">
              <span className="currency-symbol">$</span>
              <input
                type="number"
                step="0.01"
                value={amountUSD}
                onChange={(e) => setAmountUSD(e.target.value)}
                required
                placeholder="0.00"
                className="amount-input"
              />
              <span className="currency-label">USD</span>
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Accept Payment In</label>
              <select value={selectedToken} onChange={(e) => setSelectedToken(e.target.value)} className="token-select">
                <option value={TOKENS.ETH}>Ethereum (ETH)</option>
                <option value={TOKENS.BTC}>Bitcoin (BTC)</option>
                <option value={TOKENS.USDC}>USD Coin (USDC)</option>
              </select>
            </div>
            <div className="form-group">
              <label>Link Expires In</label>
              <select value={duration} onChange={(e) => setDuration(e.target.value)}>
                <option value="300">5 minutes</option>
                <option value="1800">30 minutes</option>
                <option value="3600">1 hour</option>
                <option value="86400">24 hours</option>
              </select>
            </div>
          </div>

          <button type="submit" disabled={isCreating} className="btn-primary btn-large">
            {isCreating ? 'Creating Link...' : '🔗 Generate Payment Link'}
          </button>
          {!isMerchantActive && (
            <p className="info-text">First time? We'll quickly set up your account.</p>
          )}
        </form>
      </div>

      <div className="payments-section">
        <h3>Your Payment Requests</h3>
        {merchantPayments && (merchantPayments as string[]).length > 0 ? (
          <div className="payments-list">
            {(merchantPayments as string[]).map((paymentId: string) => (
              <PaymentCard key={paymentId} paymentId={paymentId} />
            ))}
          </div>
        ) : (
          <div className="no-payments">
            <p>No payment requests yet.</p>
            <p className="subtitle">Create your first payment request above!</p>
          </div>
        )}
      </div>
    </div>
  )
}

function PaymentCard({ paymentId }: { paymentId: string }) {
  const [copied, setCopied] = useState(false)
  const [currentTime, setCurrentTime] = useState(Math.floor(Date.now() / 1000))

  const { data: payment } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'getPayment',
    args: [paymentId],
  })

  // Update current time every second to check expiration
  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentTime(Math.floor(Date.now() / 1000))
    }, 1000)
    return () => clearInterval(interval)
  }, [])

  if (!payment) return null

  const paymentData = payment as any
  const paymentUrl = `${window.location.origin}/pay/${paymentId}`

  const statusLabels = ['Pending', 'Completed', 'Failed', 'Expired', 'Refunded']

  // Check if payment has expired (client-side check)
  const isExpired = paymentData.status === 0 && Number(paymentData.expiresAt) < currentTime

  // Determine actual status
  let status = statusLabels[paymentData.status]
  if (isExpired) {
    status = 'Expired'
  }

  const getTokenSymbol = (tokenAddress: string) => {
    if (tokenAddress === TOKENS.ETH) return 'ETH'
    if (tokenAddress === TOKENS.BTC) return 'BTC'
    if (tokenAddress === TOKENS.USDC) return 'USDC'
    return 'Unknown'
  }

  const handleCopyLink = () => {
    navigator.clipboard.writeText(paymentUrl)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Payment Request',
          text: `Please pay $${(Number(paymentData.amountUSD) / 1e8).toFixed(2)} via WalletWave`,
          url: paymentUrl,
        })
      } catch (err) {
        console.log('Share failed:', err)
      }
    } else {
      handleCopyLink()
    }
  }

  return (
    <div className={`payment-card status-${status.toLowerCase()}`}>
      <div className="payment-card-header">
        <div className="amount-section">
          <span className="amount">${(Number(paymentData.amountUSD) / 1e8).toFixed(2)}</span>
          <span className="token">{getTokenSymbol(paymentData.token)}</span>
        </div>
        <span className={`status-badge status-${status.toLowerCase()}`}>{status}</span>
      </div>

      <div className="payment-details">
        <div className="detail-row">
          <span className="label">Request ID:</span>
          <span className="value">{paymentId.slice(0, 10)}...{paymentId.slice(-8)}</span>
        </div>
        {paymentData.customer !== '0x0000000000000000000000000000000000000000' && (
          <div className="detail-row">
            <span className="label">Paid by:</span>
            <span className="value">{paymentData.customer.slice(0, 6)}...{paymentData.customer.slice(-4)}</span>
          </div>
        )}
      </div>

      {status === 'Pending' && (
        <div className="payment-actions">
          <button onClick={handleCopyLink} className="btn-action">
            {copied ? '✓ Copied!' : '📋 Copy Link'}
          </button>
          <button onClick={handleShare} className="btn-action btn-primary">
            📤 Share Link
          </button>
        </div>
      )}

      {status === 'Completed' && (
        <div className="payment-success">
          ✓ Payment Received
        </div>
      )}
    </div>
  )
}