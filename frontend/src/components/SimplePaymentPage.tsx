import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { useAccount, useWriteContract, useReadContract } from 'wagmi'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'

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

export default function SimplePaymentPage() {
  const { paymentId } = useParams()
  const { address, isConnected } = useAccount()
  const [manualPaymentId, setManualPaymentId] = useState('')
  const [timeLeft, setTimeLeft] = useState<number>(0)

  const activePaymentId = paymentId || manualPaymentId

  const { data: payment, refetch: refetchPayment } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'getPayment',
    args: [activePaymentId],
  })

  const { data: isValid } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'isPaymentValid',
    args: [activePaymentId],
  })

  const { writeContract: processPayment, isPending: isProcessing } = useWriteContract()
  const { writeContract: processTokenPayment, isPending: isProcessingToken } = useWriteContract()

  const paymentData = payment as any

  // Timer countdown
  useEffect(() => {
    if (!paymentData) return

    const interval = setInterval(() => {
      const now = Math.floor(Date.now() / 1000)
      const expires = Number(paymentData.expiresAt)
      const remaining = expires - now
      setTimeLeft(remaining > 0 ? remaining : 0)
    }, 1000)

    return () => clearInterval(interval)
  }, [paymentData])

  const handlePayment = async () => {
    if (!isConnected || !paymentData) return

    try {
      const isETH = paymentData.token === TOKENS.ETH

      if (isETH) {
        await processPayment({
          address: CONTRACTS.PaymentGateway as `0x${string}`,
          abi: PaymentGatewayABI,
          functionName: 'processPayment',
          args: [activePaymentId],
          value: paymentData.amount,
        })
      } else {
        await processTokenPayment({
          address: CONTRACTS.PaymentGateway as `0x${string}`,
          abi: PaymentGatewayABI,
          functionName: 'processTokenPayment',
          args: [activePaymentId, paymentData.amount],
        })
      }

      alert('Payment submitted!')
      refetchPayment()
    } catch (error) {
      console.error('Payment error:', error)
      alert('Payment failed')
    }
  }

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  const getTokenSymbol = (tokenAddress: string) => {
    if (tokenAddress === TOKENS.ETH) return 'ETH'
    if (tokenAddress === TOKENS.BTC) return 'BTC'
    if (tokenAddress === TOKENS.USDC) return 'USDC'
    return 'Unknown'
  }

  if (!activePaymentId) {
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

        <div style={{ maxWidth: '42rem', margin: '5rem auto', padding: '2rem' }}>
          <div style={styles.glassCard}>
            <h2 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '1rem' }}>Pay Someone</h2>
            <p style={{ color: '#d1d5db', marginBottom: '1.5rem' }}>Enter the payment link or ID you received:</p>
            <input
              type="text"
              placeholder="Paste payment ID here (0x...)"
              value={manualPaymentId}
              onChange={(e) => setManualPaymentId(e.target.value)}
              style={{
                width: '100%',
                background: 'rgba(255,255,255,0.05)',
                border: '1px solid rgba(255,255,255,0.2)',
                borderRadius: '0.5rem',
                padding: '1rem',
                color: 'white',
                fontSize: '1rem',
                outline: 'none'
              }}
            />
            <p style={{ color: '#9ca3af', marginTop: '1rem', fontSize: '0.875rem' }}>💡 Or click on a payment link shared with you</p>
          </div>
        </div>
      </div>
    )
  }

  if (!payment || !paymentData.paymentId) {
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

        <div style={{ maxWidth: '42rem', margin: '5rem auto', padding: '2rem' }}>
          <div style={{ ...styles.glassCard, textAlign: 'center' }}>
            <h2 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '1rem', color: '#ef4444' }}>Payment Not Found</h2>
            <p style={{ color: '#d1d5db' }}>The payment ID you provided could not be found.</p>
          </div>
        </div>
      </div>
    )
  }

  const statusLabels = ['Pending', 'Completed', 'Failed', 'Expired', 'Refunded']
  const status = statusLabels[paymentData.status]
  const tokenSymbol = getTokenSymbol(paymentData.token)
  const tokenAmount = (Number(paymentData.amount) / 1e18).toFixed(6)
  const usdAmount = (Number(paymentData.amountUSD) / 1e8).toFixed(2)

  const statusColors = {
    Pending: '#eab308',
    Completed: '#22c55e',
    Failed: '#ef4444',
    Expired: '#6b7280',
    Refunded: '#3b82f6'
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

      <main style={{ maxWidth: '42rem', margin: '3rem auto', padding: '2rem' }}>
        <div style={styles.glassCard}>
          <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
            <h2 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '1rem' }}>
              <span style={styles.gradientText}>Payment Request</span>
            </h2>
            <div style={{
              display: 'inline-block',
              padding: '0.5rem 1rem',
              borderRadius: '9999px',
              fontSize: '0.875rem',
              fontWeight: 'bold',
              background: statusColors[status as keyof typeof statusColors],
              marginBottom: '2rem'
            }}>
              {status}
            </div>
          </div>

          {/* Amount Display */}
          <div style={{ textAlign: 'center', marginBottom: '2rem', padding: '2rem', background: 'rgba(255,255,255,0.05)', borderRadius: '1rem' }}>
            <p style={{ color: '#9ca3af', marginBottom: '0.5rem' }}>You're being asked to pay</p>
            <h1 style={{ fontSize: '4rem', fontWeight: 'bold', marginBottom: '0.5rem', ...styles.gradientText }}>${usdAmount}</h1>
            <p style={{ fontSize: '1.25rem', color: '#9ca3af' }}>≈ {tokenAmount} {tokenSymbol}</p>
          </div>

          {/* Payment Info */}
          <div style={{ display: 'grid', gap: '1rem', marginBottom: '2rem' }}>
            <div style={{ padding: '1rem', background: 'rgba(255,255,255,0.05)', borderRadius: '0.5rem' }}>
              <p style={{ fontSize: '0.875rem', color: '#9ca3af', marginBottom: '0.25rem' }}>Receiving</p>
              <p style={{ fontFamily: 'monospace', fontSize: '1.125rem' }}>
                {paymentData.merchant.slice(0, 6)}...{paymentData.merchant.slice(-4)}
              </p>
            </div>

            {paymentData.customer !== '0x0000000000000000000000000000000000000000' && (
              <div style={{ padding: '1rem', background: 'rgba(255,255,255,0.05)', borderRadius: '0.5rem' }}>
                <p style={{ fontSize: '0.875rem', color: '#9ca3af', marginBottom: '0.25rem' }}>Paid by</p>
                <p style={{ fontFamily: 'monospace', fontSize: '1.125rem' }}>
                  {paymentData.customer.slice(0, 6)}...{paymentData.customer.slice(-4)}
                </p>
              </div>
            )}

            {status === 'Pending' && timeLeft > 0 && (
              <div style={{ padding: '1rem', background: 'rgba(255,255,255,0.05)', borderRadius: '0.5rem' }}>
                <p style={{ fontSize: '0.875rem', color: '#9ca3af', marginBottom: '0.25rem' }}>Link expires in</p>
                <p style={{ fontSize: '1.5rem', fontWeight: 'bold', color: '#eab308' }}>{formatTime(timeLeft)}</p>
              </div>
            )}
          </div>

          {/* Payment Actions */}
          {status === 'Pending' && isValid && (
            <div style={{ marginBottom: '1rem' }}>
              {!isConnected ? (
                <div style={{ textAlign: 'center', padding: '2rem', background: 'rgba(234, 179, 8, 0.1)', borderRadius: '0.5rem', marginBottom: '1rem' }}>
                  <p style={{ color: '#eab308', marginBottom: '1rem' }}>🔐 Connect your wallet to pay</p>
                  <ConnectButton />
                </div>
              ) : (
                <button
                  onClick={handlePayment}
                  disabled={isProcessing || isProcessingToken}
                  style={{ ...styles.button, opacity: (isProcessing || isProcessingToken) ? 0.5 : 1, cursor: (isProcessing || isProcessingToken) ? 'not-allowed' : 'pointer' }}
                >
                  {isProcessing || isProcessingToken ? 'Processing Payment...' : `💸 Pay ${tokenAmount} ${tokenSymbol}`}
                </button>
              )}
            </div>
          )}

          {status === 'Completed' && (
            <div style={{ textAlign: 'center', padding: '2rem', background: 'rgba(34, 197, 94, 0.1)', borderRadius: '0.5rem' }}>
              <h3 style={{ fontSize: '1.5rem', fontWeight: 'bold', color: '#22c55e', marginBottom: '0.5rem' }}>✅ Payment Completed</h3>
              <p style={{ color: '#9ca3af' }}>This payment has been successfully processed.</p>
            </div>
          )}

          {status === 'Expired' && (
            <div style={{ textAlign: 'center', padding: '2rem', background: 'rgba(239, 68, 68, 0.1)', borderRadius: '0.5rem' }}>
              <h3 style={{ fontSize: '1.5rem', fontWeight: 'bold', color: '#ef4444', marginBottom: '0.5rem' }}>⏰ Link Expired</h3>
              <p style={{ color: '#9ca3af' }}>This payment link has expired. Please ask for a new one.</p>
            </div>
          )}
        </div>
      </main>
    </div>
  )
}
