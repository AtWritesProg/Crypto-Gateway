import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { useAccount, useWriteContract, useReadContract } from 'wagmi'
import { motion } from "framer-motion"
import { Zap, Clock, User } from "lucide-react"
import toast, { Toaster } from "react-hot-toast"
import AnimatedBackground from "./AnimatedBackground"
import GlassNavbar from "./GlassNavbar"
import GradientButton from "./GradientButton"
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'

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
    if (!isConnected || !paymentData) {
      toast.error("Please connect your wallet", {
        icon: "⚠️",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
      return
    }

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

      toast.success("Payment submitted!", {
        icon: "✅",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
      refetchPayment()
    } catch (error) {
      console.error('Payment error:', error)
      toast.error("Payment failed", {
        icon: "❌",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
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
      <div className="min-h-screen">
        <Toaster position="top-right" />
        <AnimatedBackground />
        <GlassNavbar />

        <main className="container mx-auto px-4 pt-32 pb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="max-w-2xl mx-auto"
          >
            <div className="glass-strong rounded-3xl p-8 border border-white/10 shadow-elevated">
              <h2 className="text-4xl font-bold gradient-text mb-4">Pay Someone</h2>
              <p className="text-muted-foreground mb-6">Enter the payment link or ID you received:</p>
              <input
                type="text"
                placeholder="Paste payment ID here (0x...)"
                value={manualPaymentId}
                onChange={(e) => setManualPaymentId(e.target.value)}
                className="w-full bg-card/50 border-2 border-white/10 focus:border-primary rounded-xl px-4 py-3 text-foreground outline-none transition-all"
              />
              <p className="text-muted-foreground text-sm mt-4">💡 Or click on a payment link shared with you</p>
            </div>
          </motion.div>
        </main>
      </div>
    )
  }

  if (!payment || !paymentData.paymentId) {
    return (
      <div className="min-h-screen">
        <Toaster position="top-right" />
        <AnimatedBackground />
        <GlassNavbar />

        <main className="container mx-auto px-4 pt-32 pb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="max-w-2xl mx-auto text-center"
          >
            <div className="glass-strong rounded-3xl p-8 border border-white/10 shadow-elevated">
              <h2 className="text-4xl font-bold text-red-500 mb-4">Payment Not Found</h2>
              <p className="text-muted-foreground">The payment ID you provided could not be found.</p>
            </div>
          </motion.div>
        </main>
      </div>
    )
  }

  const statusLabels = ['Pending', 'Completed', 'Failed', 'Expired', 'Refunded']
  const status = statusLabels[paymentData.status]
  const tokenSymbol = getTokenSymbol(paymentData.token)
  const tokenAmount = (Number(paymentData.amount) / 1e18).toFixed(6)
  const usdAmount = (Number(paymentData.amountUSD) / 1e8).toFixed(2)

  const statusColors = {
    Pending: 'text-yellow-400',
    Completed: 'text-green-400',
    Failed: 'text-red-400',
    Expired: 'text-gray-400',
    Refunded: 'text-blue-400'
  }

  return (
    <div className="min-h-screen">
      <Toaster position="top-right" />
      <AnimatedBackground />
      <GlassNavbar />

      <main className="container mx-auto px-4 pt-32 pb-16">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="max-w-2xl mx-auto"
        >
          <div className="glass-strong rounded-3xl p-8 border border-white/10 shadow-elevated">
            {/* Header */}
            <div className="text-center mb-8">
              <h2 className="text-4xl font-bold gradient-text mb-4">Payment Request</h2>
              <div className={`inline-block px-4 py-2 rounded-full text-sm font-bold ${statusColors[status as keyof typeof statusColors]} bg-card/50`}>
                {status}
              </div>
            </div>

            {/* Amount Display */}
            <div className="text-center mb-8 p-8 bg-card/30 rounded-2xl border border-white/10">
              <p className="text-muted-foreground mb-2">You're being asked to pay</p>
              <h1 className="text-6xl font-bold gradient-text mb-2">${usdAmount}</h1>
              <p className="text-xl text-muted-foreground">≈ {tokenAmount} {tokenSymbol}</p>
            </div>

            {/* Payment Info */}
            <div className="space-y-4 mb-8">
              <div className="glass rounded-xl p-4">
                <div className="flex items-center gap-3">
                  <User className="w-5 h-5 text-primary" />
                  <div>
                    <p className="text-sm text-muted-foreground">Receiving</p>
                    <p className="font-mono text-lg">{paymentData.merchant.slice(0, 6)}...{paymentData.merchant.slice(-4)}</p>
                  </div>
                </div>
              </div>

              {paymentData.customer !== '0x0000000000000000000000000000000000000000' && (
                <div className="glass rounded-xl p-4">
                  <div className="flex items-center gap-3">
                    <User className="w-5 h-5 text-cyan" />
                    <div>
                      <p className="text-sm text-muted-foreground">Paid by</p>
                      <p className="font-mono text-lg">{paymentData.customer.slice(0, 6)}...{paymentData.customer.slice(-4)}</p>
                    </div>
                  </div>
                </div>
              )}

              {status === 'Pending' && timeLeft > 0 && (
                <div className="glass rounded-xl p-4">
                  <div className="flex items-center gap-3">
                    <Clock className="w-5 h-5 text-yellow-400" />
                    <div>
                      <p className="text-sm text-muted-foreground">Link expires in</p>
                      <p className="text-2xl font-bold text-yellow-400">{formatTime(timeLeft)}</p>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Payment Actions */}
            {status === 'Pending' && isValid && (
              <div className="mb-4">
                {!isConnected ? (
                  <div className="text-center p-6 bg-yellow-400/10 rounded-xl border border-yellow-400/20 mb-4">
                    <p className="text-yellow-400 mb-4">🔐 Connect your wallet to pay</p>
                  </div>
                ) : (
                  <GradientButton
                    onClick={handlePayment}
                    disabled={isProcessing || isProcessingToken}
                    size="xl"
                    icon={<Zap className="w-6 h-6" />}
                  >
                    {isProcessing || isProcessingToken ? 'Processing Payment...' : `Pay ${tokenAmount} ${tokenSymbol}`}
                  </GradientButton>
                )}
              </div>
            )}

            {status === 'Completed' && (
              <div className="text-center p-6 bg-green-400/10 rounded-xl border border-green-400/20">
                <h3 className="text-2xl font-bold text-green-400 mb-2">✅ Payment Completed</h3>
                <p className="text-muted-foreground">This payment has been successfully processed.</p>
              </div>
            )}

            {status === 'Expired' && (
              <div className="text-center p-6 bg-red-400/10 rounded-xl border border-red-400/20">
                <h3 className="text-2xl font-bold text-red-400 mb-2">⏰ Link Expired</h3>
                <p className="text-muted-foreground">This payment link has expired. Please ask for a new one.</p>
              </div>
            )}
          </div>
        </motion.div>
      </main>
    </div>
  )
}
