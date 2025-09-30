import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { useAccount, useWriteContract, useReadContract } from 'wagmi'
import { parseEther } from 'viem'
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'

export default function PaymentPage() {
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
      <div className="payment-container">
        <div className="payment-lookup">
          <h2>Make a Payment</h2>
          <p>Enter a payment ID to proceed:</p>
          <div className="form">
            <input
              type="text"
              placeholder="0x..."
              value={manualPaymentId}
              onChange={(e) => setManualPaymentId(e.target.value)}
              className="payment-id-input"
            />
          </div>
        </div>
      </div>
    )
  }

  if (!payment || !paymentData.paymentId) {
    return (
      <div className="payment-container">
        <div className="error-message">
          <h2>Payment Not Found</h2>
          <p>The payment ID you provided could not be found.</p>
        </div>
      </div>
    )
  }

  const statusLabels = ['Pending', 'Completed', 'Failed', 'Expired', 'Refunded']
  const status = statusLabels[paymentData.status]
  const tokenSymbol = getTokenSymbol(paymentData.token)
  const tokenAmount = (Number(paymentData.amount) / 1e18).toFixed(6)
  const usdAmount = (Number(paymentData.amountUSD) / 1e8).toFixed(2)

  return (
    <div className="payment-container">
      <div className="payment-details">
        <h2>Payment Details</h2>

        <div className="payment-status-badge" data-status={status.toLowerCase()}>
          {status}
        </div>

        <div className="payment-info-grid">
          <div className="info-item">
            <label>Amount</label>
            <p className="amount-display">{tokenAmount} {tokenSymbol}</p>
            <p className="usd-display">${usdAmount} USD</p>
          </div>

          <div className="info-item">
            <label>Merchant</label>
            <p className="address">{paymentData.merchant.slice(0, 6)}...{paymentData.merchant.slice(-4)}</p>
          </div>

          {paymentData.customer !== '0x0000000000000000000000000000000000000000' && (
            <div className="info-item">
              <label>Customer</label>
              <p className="address">{paymentData.customer.slice(0, 6)}...{paymentData.customer.slice(-4)}</p>
            </div>
          )}

          {status === 'Pending' && timeLeft > 0 && (
            <div className="info-item">
              <label>Time Remaining</label>
              <p className="timer">{formatTime(timeLeft)}</p>
            </div>
          )}
        </div>

        {status === 'Pending' && isValid && (
          <div className="payment-actions">
            {!isConnected ? (
              <p className="warning">Please connect your wallet to make payment</p>
            ) : (
              <button
                onClick={handlePayment}
                disabled={isProcessing || isProcessingToken}
                className="btn-primary btn-large"
              >
                {isProcessing || isProcessingToken ? 'Processing...' : `Pay ${tokenAmount} ${tokenSymbol}`}
              </button>
            )}
          </div>
        )}

        {status === 'Completed' && (
          <div className="success-message">
            <h3>✅ Payment Completed</h3>
            <p>This payment has been successfully processed.</p>
          </div>
        )}

        {status === 'Expired' && (
          <div className="error-message">
            <h3>⏰ Payment Expired</h3>
            <p>This payment link has expired. Please request a new one.</p>
          </div>
        )}
      </div>
    </div>
  )
}