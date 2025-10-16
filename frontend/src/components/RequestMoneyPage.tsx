import { useState, useEffect, useMemo } from 'react'
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt, useReadContracts } from 'wagmi'
import { motion } from 'framer-motion'
import { Zap, ChevronDown } from 'lucide-react'
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'
import MerchantRegistryABI from '../contracts/MerchantRegistry.json'
import AnimatedBackground from './AnimatedBackground'
import GlassNavbar from './GlassNavbar'
import AmountInput from './AmountInput'
import IntegratedPaymentCard from './IntegratedPaymentCard'
import GradientButton from './GradientButton'

export default function RequestMoneyPage() {
  const { address, isConnected } = useAccount()
  const [amount, setAmount] = useState('')
  const [currency, setCurrency] = useState<`0x${string}`>(TOKENS.ETH as `0x${string}`)
  const [validity, setValidity] = useState('1800') // 30 minutes
  const [showRegistration, setShowRegistration] = useState(false)
  const [businessName, setBusinessName] = useState('')
  const [email, setEmail] = useState('')

  const { writeContract: registerMerchant, isPending: isRegistering, data: registerHash } = useWriteContract()
  const { writeContract: createPayment, isPending: isCreating, data: createPaymentHash } = useWriteContract()

  const { isSuccess: isRegisterSuccess } = useWaitForTransactionReceipt({
    hash: registerHash,
  })

  const { isSuccess: isCreatePaymentSuccess } = useWaitForTransactionReceipt({
    hash: createPaymentHash,
  })

  const { data: isMerchantActive, refetch: refetchMerchantStatus } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
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

  // Fetch all payment details to sort them
  const paymentIds = (merchantPayments as string[]) || []
  const { data: paymentsData } = useReadContracts({
    contracts: paymentIds.map((paymentId) => ({
      address: CONTRACTS.PaymentGateway as `0x${string}`,
      abi: PaymentGatewayABI as any,
      functionName: 'getPayment',
      args: [paymentId],
    })),
    query: {
      refetchInterval: 5000, // Refetch every 5 seconds to keep status updated
    }
  })

  // Sort payments: pending first, then expired, then paid/completed
  const sortedPaymentIds = useMemo(() => {
    if (!paymentIds.length || !paymentsData) return paymentIds

    const paymentWithStatus = paymentIds.map((id, index) => {
      const paymentData = paymentsData[index]?.result as any
      const status = paymentData?.status ?? 0
      const expiresAt = paymentData?.expiresAt ? Number(paymentData.expiresAt) : 0
      const currentTime = Math.floor(Date.now() / 1000)
      const hasExpired = expiresAt > 0 && expiresAt < currentTime

      // Status priority: 0=pending, 1=completed, 2=failed, 3=expired, 4=refunded
      // If status is pending but expired, treat as expired
      let sortPriority = status
      if (status === 0 && hasExpired) {
        sortPriority = 3 // expired
      }

      return { id, status: sortPriority, timestamp: expiresAt }
    })

    // Sort: pending (0) first, then failed (2), expired (3), refunded (4), completed (1) last
    const priorityOrder = [0, 2, 3, 4, 1]
    return paymentWithStatus
      .sort((a, b) => {
        const aPriority = priorityOrder.indexOf(a.status)
        const bPriority = priorityOrder.indexOf(b.status)
        if (aPriority !== bPriority) {
          return aPriority - bPriority
        }
        // Within same status, sort by timestamp (newest first)
        return b.timestamp - a.timestamp
      })
      .map(p => p.id)
  }, [paymentIds, paymentsData])

  useEffect(() => {
    if (isRegisterSuccess) {
      refetchMerchantStatus()
      setShowRegistration(false)
    }
  }, [isRegisterSuccess, refetchMerchantStatus])

  useEffect(() => {
    if (isCreatePaymentSuccess) {
      // Multiple refetches with delays to ensure blockchain state has propagated
      setTimeout(() => {
        refetchPayments()
        alert('Payment link generated! 🎉')
      }, 1000)
      // Additional refetches to ensure new card data is loaded
      setTimeout(() => refetchPayments(), 2000)
      setTimeout(() => refetchPayments(), 3000)
    }
  }, [isCreatePaymentSuccess, refetchPayments])

  const handleGenerateLink = async () => {
    if (!isConnected) return

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
      setAmount('')
      // Success alert and refetch will happen in useEffect after transaction confirmation
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
      <div className="min-h-screen">
        <AnimatedBackground />
        <GlassNavbar />
        <div className="container mx-auto px-4 pt-32 text-center">
          <h1 className="text-5xl md:text-7xl font-bold mb-4">
            <span className="gradient-text text-glow">Welcome to WalletWave</span>
          </h1>
          <p className="text-xl text-muted-foreground">Connect your wallet to start requesting payments</p>
        </div>
      </div>
    )
  }

  if (showRegistration && !isMerchantActive) {
    return (
      <div className="min-h-screen">
        <AnimatedBackground />
        <GlassNavbar />
        <div className="container mx-auto px-4 pt-32">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="max-w-md mx-auto"
          >
            <div className="glass-strong rounded-3xl p-8 shadow-elevated border-glow">
              <h2 className="text-2xl font-bold gradient-text mb-4">Quick Setup</h2>
              <p className="text-muted-foreground mb-6">Before creating your first payment request:</p>
              <form onSubmit={handleRegister} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Your Name / Business Name</label>
                  <input
                    type="text"
                    value={businessName}
                    onChange={(e) => setBusinessName(e.target.value)}
                    required
                    className="w-full glass-strong rounded-lg px-4 py-3 border border-white/10 focus:border-primary outline-none"
                    placeholder="John Doe or Your Business"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-2">Email</label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    className="w-full glass-strong rounded-lg px-4 py-3 border border-white/10 focus:border-primary outline-none"
                    placeholder="your@email.com"
                  />
                </div>
                <div className="flex gap-3">
                  <button
                    type="button"
                    onClick={() => setShowRegistration(false)}
                    className="flex-1 glass rounded-lg px-4 py-3 font-semibold"
                  >
                    Cancel
                  </button>
                  <GradientButton type="submit" disabled={isRegistering} className="flex-1">
                    {isRegistering ? 'Setting up...' : 'Complete Setup'}
                  </GradientButton>
                </div>
              </form>
            </div>
          </motion.div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen">
      <AnimatedBackground />
      <GlassNavbar />

      <main className="container mx-auto px-4 pt-32 pb-16">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <h1 className="text-5xl md:text-7xl font-bold mb-4">
            <span className="gradient-text text-glow">✨ Request Money</span>
          </h1>
          <p className="text-xl text-muted-foreground flex items-center justify-center gap-2">
            💎 Your Wallet: <span className="font-mono">{address?.slice(0, 6)}...{address?.slice(-4)}</span>
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="max-w-2xl mx-auto mb-16"
        >
          <div className="glass-strong rounded-3xl p-8 shadow-elevated border-glow">
            <h2 className="text-2xl font-bold gradient-text mb-6 uppercase tracking-wider">
              Create New Request
            </h2>

            <div className="mb-6">
              <AmountInput value={amount} onChange={setAmount} />
            </div>

            <div className="grid md:grid-cols-2 gap-4 mb-8">
              <div className="glass rounded-xl p-4">
                <label className="block text-sm font-medium text-muted-foreground mb-2 uppercase tracking-wider">
                  Get paid in:
                </label>
                <div className="relative">
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value as `0x${string}`)}
                    className="w-full glass-strong rounded-lg px-4 py-3 appearance-none cursor-pointer font-bold text-lg bg-transparent border border-white/10 focus:border-primary transition-all outline-none"
                  >
                    <option value={TOKENS.ETH}>🟣 ETH</option>
                    <option value={TOKENS.BTC}>🟠 BTC</option>
                    <option value={TOKENS.USDC}>🔵 USDC</option>
                  </select>
                  <ChevronDown className="absolute right-4 top-1/2 -translate-y-1/2 h-5 w-5 pointer-events-none text-primary" />
                </div>
              </div>

              <div className="glass rounded-xl p-4">
                <label className="block text-sm font-medium text-muted-foreground mb-2 uppercase tracking-wider">
                  Valid for:
                </label>
                <div className="relative">
                  <select
                    value={validity}
                    onChange={(e) => setValidity(e.target.value)}
                    className="w-full glass-strong rounded-lg px-4 py-3 appearance-none cursor-pointer font-bold text-lg bg-transparent border border-white/10 focus:border-cyan transition-all outline-none"
                  >
                    <option value="300">⏰ 5 min</option>
                    <option value="1800">⏰ 30 min</option>
                    <option value="3600">⏰ 1 hour</option>
                    <option value="86400">⏰ 24 hours</option>
                  </select>
                  <ChevronDown className="absolute right-4 top-1/2 -translate-y-1/2 h-5 w-5 pointer-events-none text-cyan" />
                </div>
              </div>
            </div>

            <GradientButton
              size="xl"
              icon={<Zap className="h-6 w-6" />}
              onClick={handleGenerateLink}
              className="w-full"
              disabled={isCreating}
            >
              {isCreating ? 'CREATING...' : 'GENERATE PAYMENT LINK'}
            </GradientButton>
          </div>
        </motion.div>

        <div className="max-w-6xl mx-auto">
          <motion.h2
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
            className="text-3xl font-bold gradient-text-accent mb-8 text-center uppercase tracking-wider"
          >
            Your Requests
          </motion.h2>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="grid md:grid-cols-2 lg:grid-cols-3 gap-6"
          >
            {sortedPaymentIds && sortedPaymentIds.length > 0 ? (
              sortedPaymentIds.map((paymentId: string, index: number) => (
                <motion.div
                  key={paymentId}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.6 + index * 0.1 }}
                >
                  <IntegratedPaymentCard paymentId={paymentId} />
                </motion.div>
              ))
            ) : (
              <div className="col-span-full text-center text-muted-foreground">
                <p>No payment requests yet. Create one above!</p>
              </div>
            )}
          </motion.div>
        </div>
      </main>
    </div>
  )
}
