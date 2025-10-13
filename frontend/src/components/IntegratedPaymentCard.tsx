import { motion } from 'framer-motion'
import { Copy, Share2, Check, Clock, X } from 'lucide-react'
import { useState } from 'react'
import { useReadContract } from 'wagmi'
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'

interface IntegratedPaymentCardProps {
  paymentId: string
}

export default function IntegratedPaymentCard({ paymentId }: IntegratedPaymentCardProps) {
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

  const currency = getTokenSymbol(paymentData.token) as 'ETH' | 'BTC' | 'USDC'
  const amount = (Number(paymentData.amountUSD) / 1e8).toFixed(2)
  const statusLabels = ['pending', 'paid', 'failed', 'expired', 'refunded']
  const status = statusLabels[paymentData.status] as 'paid' | 'pending' | 'expired'

  const currencyColors = {
    ETH: 'from-primary to-cyan',
    BTC: 'from-orange-500 to-yellow-500',
    USDC: 'from-blue-500 to-cyan',
  }

  const currencyIcons = {
    ETH: '🟣',
    BTC: '🟠',
    USDC: '🔵',
  }

  const statusConfig = {
    paid: {
      icon: Check,
      label: 'PAID',
      color: 'from-accent-lime to-green-500',
      glow: 'shadow-[0_0_20px_rgba(132,204,22,0.4)]',
      pulse: false,
    },
    pending: {
      icon: Clock,
      label: 'PENDING',
      color: 'from-yellow-500 to-orange-500',
      glow: 'shadow-[0_0_20px_rgba(251,191,36,0.4)]',
      pulse: true,
    },
    expired: {
      icon: X,
      label: 'EXPIRED',
      color: 'from-red-600 to-red-900',
      glow: 'shadow-[0_0_20px_rgba(220,38,38,0.4)]',
      pulse: false,
    },
  }

  const StatusIcon = statusConfig[status]?.icon || Clock

  const handleCopy = () => {
    navigator.clipboard.writeText(paymentUrl)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Payment Request',
          text: `Please pay $${amount} via WalletWave`,
          url: paymentUrl,
        })
      } catch (err) {
        console.log('Share failed:', err)
        handleCopy()
      }
    } else {
      handleCopy()
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -5 }}
      className="perspective-1000"
    >
      <div
        className={`
          glass-strong rounded-2xl p-6 shadow-glass
          border-2 bg-gradient-to-br ${currencyColors[currency]}
          ${statusConfig[status]?.glow}
        `}
      >
        {/* Status Badge */}
        <div className="flex items-center justify-between mb-4">
          <motion.div
            animate={statusConfig[status]?.pulse ? { scale: [1, 1.05, 1] } : {}}
            transition={{ duration: 2, repeat: Infinity }}
            className={`
              flex items-center gap-2 px-3 py-1 rounded-full
              bg-gradient-to-r ${statusConfig[status]?.color}
              text-xs font-bold
            `}
          >
            <StatusIcon className="h-3 w-3" />
            {statusConfig[status]?.label}
          </motion.div>
          <span className="text-2xl">{currencyIcons[currency]}</span>
        </div>

        {/* Amount */}
        <div className="mb-4">
          <motion.div
            className="text-4xl font-bold mb-1"
            whileHover={{ scale: 1.05 }}
          >
            💰 ${amount}
          </motion.div>
          <div className="text-sm text-foreground/70">
            {currency} Payment
          </div>
        </div>

        {/* Additional Info */}
        {paymentData.customer !== '0x0000000000000000000000000000000000000000' && (
          <div className="mb-3 text-sm">
            <span className="text-foreground/60">From: </span>
            <span className="font-mono">{paymentData.customer.slice(0, 6)}...{paymentData.customer.slice(-4)}</span>
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex gap-2 mt-4">
          {status === 'paid' && (
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleCopy}
              className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
            >
              <Copy className="h-4 w-4 inline mr-1" />
              {copied ? 'Copied!' : 'Copy'}
            </motion.button>
          )}
          {status === 'pending' && (
            <>
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={handleCopy}
                className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
              >
                <Copy className="h-4 w-4 inline mr-1" />
                {copied ? '✓' : 'Copy'}
              </motion.button>
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={handleShare}
                className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
              >
                <Share2 className="h-4 w-4 inline mr-1" />
                Share
              </motion.button>
            </>
          )}
        </div>
      </div>
    </motion.div>
  )
}
