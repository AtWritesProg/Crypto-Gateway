import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'
import MerchantRegistryABI from '../contracts/MerchantRegistry.json'

const styles = {
  container: {
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #1e1b4b 0%, #1e3a8a 50%, #000000 100%)',
    color: 'white'
  },
  header: {
    borderBottom: '1px solid rgba(255,255,255,0.1)',
    background: 'rgba(255,255,255,0.05)',
    backdropFilter: 'blur(10px)'
  },
  gradientText: {
    background: 'linear-gradient(to right, #c084fc, #22d3ee)',
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
    backgroundClip: 'text'
  },
  glassCard: {
    background: 'rgba(255,255,255,0.1)',
    backdropFilter: 'blur(20px)',
    borderRadius: '1.5rem',
    padding: '2rem',
    border: '1px solid rgba(255,255,255,0.2)',
    boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5)'
  },
  input: {
    width: '100%',
    background: 'rgba(255,255,255,0.05)',
    border: '1px solid rgba(255,255,255,0.2)',
    borderRadius: '0.5rem',
    padding: '0.75rem 1rem',
    color: 'white',
    outline: 'none'
  },
  button: {
    width: '100%',
    background: 'linear-gradient(to right, #8b5cf6, #06b6d4)',
    borderRadius: '0.5rem',
    padding: '1rem 1.5rem',
    fontSize: '1.25rem',
    fontWeight: 'bold',
    color: 'white',
    border: 'none',
    cursor: 'pointer',
    boxShadow: '0 10px 25px -5px rgba(139, 92, 246, 0.5)'
  }
}

export default function SimpleRequestPage() {
  const { address, isConnected } = useAccount()
  const [amount, setAmount] = useState('')
  const [currency, setCurrency] = useState<`0x${string}`>(TOKENS.ETH as `0x${string}`)
  const [validity, setValidity] = useState('1800')
  const [showRegistration, setShowRegistration] = useState(false)
  const [businessName, setBusinessName] = useState('')
  const [email, setEmail] = useState('')

  const { writeContract: registerMerchant, isPending: isRegistering, data: registerHash } = useWriteContract()
  const { writeContract: createPayment, isPending: isCreating } = useWriteContract()

  const { isSuccess: isRegisterSuccess } = useWaitForTransactionReceipt({
    hash: registerHash,
  })

  const { data: isMerchantActive, refetch: refetchMerchantStatus } = useReadContract({
    address: CONTRACTS.MerchantRegistry as `0x${string}`,
    abi: MerchantRegistryABI,
    functionName: 'isMerchantActive',
    args: [address],
  })

  const { data: merchantPayments, refetch: refetchPayments } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'getMerchantPayments',
    args: [address],
  })

  useEffect(() => {
    if (isRegisterSuccess) {
      refetchMerchantStatus()
      setShowRegistration(false)
    }
  }, [isRegisterSuccess, refetchMerchantStatus])

  const handleGenerateLink = async () => {
    if (!isConnected) {
      alert('Please connect your wallet first')
      return
    }

    if (!amount) {
      alert('Please enter an amount')
      return
    }

    if (!isMerchantActive) {
      setShowRegistration(true)
      return
    }

    try {
      const usdAmount = BigInt(Math.floor(parseFloat(amount) * 1e8))
      await createPayment({
        address: CONTRACTS.PaymentGateway as `0x${string}`,
        abi: PaymentGatewayABI,
        functionName: 'createPayment',
        args: [currency, usdAmount, Number(validity)],
      })
      alert('Payment link generated! 🎉')
      refetchPayments()
      setAmount('')
    } catch (error) {
      console.error('Error creating payment:', error)
      alert('Failed to create payment')
    }
  }

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      await registerMerchant({
        address: CONTRACTS.MerchantRegistry as `0x${string}`,
        abi: MerchantRegistryABI,
        functionName: 'registerMerchant',
        args: [businessName, email],
      })
    } catch (error) {
      console.error('Registration error:', error)
      alert('Registration failed')
    }
  }

  if (!isConnected) {
    return (
      <div style={styles.container}>
        <div style={{ textAlign: 'center', padding: '5rem 1rem' }}>
          <h1 style={{ ...styles.gradientText, fontSize: '4rem', fontWeight: 'bold', marginBottom: '2rem' }}>
            WalletWave
          </h1>
          <p style={{ fontSize: '1.5rem', marginBottom: '2rem' }}>Connect your wallet to start requesting payments</p>
          <ConnectButton />
        </div>
      </div>
    )
  }

  if (showRegistration && !isMerchantActive) {
    return (
      <div style={styles.container}>
        <div style={{ padding: '5rem 1rem' }}>
          <div style={{ ...styles.glassCard, maxWidth: '28rem', margin: '0 auto' }}>
            <h2 style={{ fontSize: '1.875rem', fontWeight: 'bold', marginBottom: '1rem' }}>Quick Setup</h2>
            <p style={{ color: '#d1d5db', marginBottom: '1.5rem' }}>Before creating your first payment request:</p>
            <form onSubmit={handleRegister} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: '500', marginBottom: '0.5rem' }}>
                  Your Name / Business Name
                </label>
                <input
                  type="text"
                  value={businessName}
                  onChange={(e) => setBusinessName(e.target.value)}
                  required
                  style={styles.input}
                  placeholder="John Doe or Your Business"
                />
              </div>
              <div>
                <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: '500', marginBottom: '0.5rem' }}>
                  Email
                </label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  style={styles.input}
                  placeholder="your@email.com"
                />
              </div>
              <div style={{ display: 'flex', gap: '0.75rem', paddingTop: '1rem' }}>
                <button
                  type="button"
                  onClick={() => setShowRegistration(false)}
                  style={{ flex: 1, ...styles.input, padding: '0.75rem', cursor: 'pointer' }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isRegistering}
                  style={{ flex: 1, ...styles.button, padding: '0.75rem', opacity: isRegistering ? 0.5 : 1 }}
                >
                  {isRegistering ? 'Setting up...' : 'Complete Setup'}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '1rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h1 style={{ ...styles.gradientText, fontSize: '1.5rem', fontWeight: 'bold' }}>
            💳 WalletWave
          </h1>
          <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
            <a href="/" style={{ color: 'white', textDecoration: 'none', padding: '0.5rem 1rem', borderRadius: '0.5rem', background: 'rgba(255,255,255,0.1)' }}>
              Request Money
            </a>
            <a href="/pay" style={{ color: 'white', textDecoration: 'none', padding: '0.5rem 1rem', borderRadius: '0.5rem', background: 'rgba(255,255,255,0.1)' }}>
              Pay Someone
            </a>
            <ConnectButton />
          </div>
        </div>
      </div>

      <main style={{ maxWidth: '1280px', margin: '0 auto', padding: '4rem 1rem' }}>
        {/* Title */}
        <div style={{ textAlign: 'center', marginBottom: '3rem' }}>
          <h2 style={{ fontSize: '3rem', fontWeight: 'bold', marginBottom: '1rem' }}>
            <span style={styles.gradientText}>✨ Request Money</span>
          </h2>
          <p style={{ fontSize: '1.25rem', color: '#d1d5db' }}>
            💎 Your Wallet: <span style={{ fontFamily: 'monospace' }}>{address?.slice(0, 6)}...{address?.slice(-4)}</span>
          </p>
        </div>

        {/* Create Request Form */}
        <div style={{ maxWidth: '42rem', margin: '0 auto 4rem' }}>
          <div style={styles.glassCard}>
            <h3 style={{ ...styles.gradientText, fontSize: '1.5rem', fontWeight: 'bold', marginBottom: '1.5rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
              Create New Request
            </h3>

            {/* Amount Input */}
            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: '500', marginBottom: '0.5rem' }}>
                How much do you want to receive?
              </label>
              <div style={{ position: 'relative' }}>
                <span style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', fontSize: '1.875rem' }}>$</span>
                <input
                  type="number"
                  step="0.01"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  style={{ ...styles.input, padding: '1rem 3rem', fontSize: '1.875rem', fontWeight: 'bold' }}
                  placeholder="0.00"
                />
                <span style={{ position: 'absolute', right: '1rem', top: '50%', transform: 'translateY(-50%)', color: '#9ca3af' }}>USD</span>
              </div>
            </div>

            {/* Token & Validity */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: '500', marginBottom: '0.5rem', textTransform: 'uppercase' }}>
                  Get paid in:
                </label>
                <select value={currency} onChange={(e) => setCurrency(e.target.value as `0x${string}`)} style={{ ...styles.input, fontWeight: 'bold', fontSize: '1.125rem', cursor: 'pointer' }}>
                  <option value={TOKENS.ETH} style={{ background: '#1e1b4b' }}>🟣 ETH</option>
                  <option value={TOKENS.BTC} style={{ background: '#1e1b4b' }}>🟠 BTC</option>
                  <option value={TOKENS.USDC} style={{ background: '#1e1b4b' }}>🔵 USDC</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: '500', marginBottom: '0.5rem', textTransform: 'uppercase' }}>
                  Valid for:
                </label>
                <select value={validity} onChange={(e) => setValidity(e.target.value)} style={{ ...styles.input, fontWeight: 'bold', fontSize: '1.125rem', cursor: 'pointer' }}>
                  <option value="300" style={{ background: '#1e1b4b' }}>⏰ 5 min</option>
                  <option value="1800" style={{ background: '#1e1b4b' }}>⏰ 30 min</option>
                  <option value="3600" style={{ background: '#1e1b4b' }}>⏰ 1 hour</option>
                  <option value="86400" style={{ background: '#1e1b4b' }}>⏰ 24 hours</option>
                </select>
              </div>
            </div>

            {/* Generate Button */}
            <button onClick={handleGenerateLink} disabled={isCreating} style={{ ...styles.button, opacity: isCreating ? 0.5 : 1, cursor: isCreating ? 'not-allowed' : 'pointer' }}>
              {isCreating ? '⏳ CREATING...' : '⚡ GENERATE PAYMENT LINK'}
            </button>
          </div>
        </div>

        {/* Payment Requests */}
        <div style={{ maxWidth: '80rem', margin: '0 auto' }}>
          <h3 style={{ fontSize: '1.875rem', fontWeight: 'bold', marginBottom: '2rem', textAlign: 'center', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
            <span style={{ background: 'linear-gradient(to right, #f472b6, #fbbf24)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
              Your Requests
            </span>
          </h3>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '1.5rem' }}>
            {merchantPayments && (merchantPayments as string[]).length > 0 ? (
              (merchantPayments as string[]).map((paymentId: string) => (
                <PaymentRequestCard key={paymentId} paymentId={paymentId} />
              ))
            ) : (
              <div style={{ gridColumn: '1 / -1', textAlign: 'center', color: '#9ca3af', padding: '3rem' }}>
                <p style={{ fontSize: '1.25rem' }}>No payment requests yet.</p>
                <p>Create your first one above!</p>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  )
}

function PaymentRequestCard({ paymentId }: { paymentId: string }) {
  const [copied, setCopied] = useState(false)

  const { data: payment } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'getPayment',
    args: [paymentId],
  })

  if (!payment) return null

  const paymentData = payment as any
  const paymentUrl = `${window.location.origin}/pay/${paymentId}`

  const getTokenSymbol = (tokenAddress: string) => {
    if (tokenAddress === TOKENS.ETH) return 'ETH'
    if (tokenAddress === TOKENS.BTC) return 'BTC'
    if (tokenAddress === TOKENS.USDC) return 'USDC'
    return 'Unknown'
  }

  const currency = getTokenSymbol(paymentData.token)
  const amount = (Number(paymentData.amountUSD) / 1e8).toFixed(2)
  const statusLabels = ['Pending', 'Completed', 'Failed', 'Expired', 'Refunded']
  const status = statusLabels[paymentData.status]

  const statusColors = {
    Pending: '#eab308',
    Completed: '#22c55e',
    Failed: '#ef4444',
    Expired: '#6b7280',
    Refunded: '#3b82f6'
  }

  const handleCopy = () => {
    navigator.clipboard.writeText(paymentUrl)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div style={{
      background: 'rgba(255,255,255,0.1)',
      backdropFilter: 'blur(20px)',
      borderRadius: '1rem',
      padding: '1.5rem',
      border: '1px solid rgba(255,255,255,0.2)',
      boxShadow: '0 10px 15px -3px rgba(0, 0, 0, 0.3)',
      color: 'white'
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem' }}>
        <span style={{
          padding: '0.25rem 0.75rem',
          borderRadius: '9999px',
          fontSize: '0.75rem',
          fontWeight: 'bold',
          background: statusColors[status as keyof typeof statusColors]
        }}>
          {status}
        </span>
        <span style={{ fontSize: '1.5rem' }}>
          {currency === 'ETH' ? '🟣' : currency === 'BTC' ? '🟠' : '🔵'}
        </span>
      </div>

      <div style={{ marginBottom: '1rem' }}>
        <div style={{ fontSize: '2.25rem', fontWeight: 'bold', marginBottom: '0.25rem' }}>💰 ${amount}</div>
        <div style={{ fontSize: '0.875rem', color: '#9ca3af' }}>{currency} Payment</div>
      </div>

      {paymentData.customer !== '0x0000000000000000000000000000000000000000' && (
        <div style={{ marginBottom: '0.75rem', fontSize: '0.875rem' }}>
          <span style={{ color: '#9ca3af' }}>From: </span>
          <span style={{ fontFamily: 'monospace' }}>{paymentData.customer.slice(0, 6)}...{paymentData.customer.slice(-4)}</span>
        </div>
      )}

      {status === 'Pending' && (
        <button
          onClick={handleCopy}
          style={{
            width: '100%',
            background: 'rgba(255,255,255,0.1)',
            borderRadius: '0.5rem',
            padding: '0.5rem 1rem',
            fontSize: '0.875rem',
            fontWeight: '500',
            color: 'white',
            border: 'none',
            cursor: 'pointer'
          }}
        >
          {copied ? '✓ Copied!' : '📋 Copy Link'}
        </button>
      )}
    </div>
  )
}
