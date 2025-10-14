import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Zap, ChevronDown } from "lucide-react";
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi'
import AnimatedBackground from "../components/AnimatedBackground";
import GlassNavbar from "../components/GlassNavbar";
import AmountInput from "../components/AmountInput";
import GradientButton from "../components/GradientButton";
import toast, { Toaster } from "react-hot-toast";
import { CONTRACTS, TOKENS } from '../contracts/config'
import PaymentGatewayABI from '../contracts/PaymentGateway.json'
import MerchantRegistryABI from '../contracts/MerchantRegistry.json'

const RequestMoney = () => {
  const { address, isConnected } = useAccount()
  const [amount, setAmount] = useState("");
  const [currency, setCurrency] = useState(TOKENS.ETH);
  const [validity, setValidity] = useState("1800");
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
      toast.success("Registration successful!", {
        icon: "✅",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
    }
  }, [isRegisterSuccess, refetchMerchantStatus])

  const handleGenerateLink = async () => {
    if (!isConnected) {
      toast.error("Please connect your wallet", {
        icon: "⚠️",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
      return;
    }

    if (!amount) {
      toast.error("Please enter an amount", {
        icon: "⚠️",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
      return;
    }

    if (!isMerchantActive) {
      setShowRegistration(true)
      return;
    }

    try {
      const usdAmount = BigInt(Math.floor(parseFloat(amount) * 1e8))
      await createPayment({
        address: CONTRACTS.PaymentGateway as `0x${string}`,
        abi: PaymentGatewayABI,
        functionName: 'createPayment',
        args: [currency, usdAmount, Number(validity)],
      })

      toast.success("Payment link generated!", {
        icon: "🎉",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });

      refetchPayments()
      setAmount('')
    } catch (error) {
      console.error('Create payment error:', error)
      toast.error("Payment creation failed", {
        icon: "❌",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
    }
  };

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
      toast.error("Registration failed", {
        icon: "❌",
        style: {
          background: "hsl(var(--card))",
          color: "hsl(var(--foreground))",
          border: "1px solid rgba(255,255,255,0.1)",
        },
      });
    }
  }

  // Registration Modal
  if (showRegistration && !isMerchantActive) {
    return (
      <div className="min-h-screen">
        <Toaster position="top-right" />
        <AnimatedBackground />
        <GlassNavbar />

        <main className="container mx-auto px-4 pt-32 pb-16">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="max-w-md mx-auto"
          >
            <div className="glass-strong rounded-3xl p-8 shadow-elevated border-glow">
              <h2 className="text-2xl font-bold gradient-text mb-4">Quick Setup - Almost There!</h2>
              <p className="text-muted-foreground mb-6">Before creating your first payment request, we need a few details:</p>
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
                  <label className="block text-sm font-medium mb-2">Email (for notifications)</label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    className="w-full glass-strong rounded-lg px-4 py-3 border border-white/10 focus:border-primary outline-none"
                    placeholder="your@email.com"
                  />
                </div>
                <div className="flex gap-3 pt-4">
                  <button
                    type="button"
                    onClick={() => setShowRegistration(false)}
                    className="flex-1 glass rounded-lg px-4 py-3 font-semibold hover:bg-white/10 transition"
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
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen">
      <Toaster position="top-right" />
      <AnimatedBackground />
      <GlassNavbar />

      <main className="container mx-auto px-4 pt-32 pb-16">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <h1 className="text-5xl md:text-7xl font-bold mb-4">
            <span className="gradient-text text-glow">✨ Request Money</span>
          </h1>
          <p className="text-xl text-muted-foreground flex items-center justify-center gap-2">
            💎 Your Wallet: <span className="font-mono">{address ? `${address.slice(0, 6)}...${address.slice(-4)}` : 'Not connected'}</span>
          </p>
        </motion.div>

        {/* Create Request Form */}
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

            {/* Amount Input */}
            <div className="mb-6">
              <AmountInput value={amount} onChange={setAmount} />
            </div>

            {/* Currency & Validity */}
            <div className="grid md:grid-cols-2 gap-4 mb-8">
              {/* Currency Select */}
              <div className="glass rounded-xl p-4">
                <label className="block text-sm font-medium text-muted-foreground mb-2 uppercase tracking-wider">
                  Get paid in:
                </label>
                <div className="relative">
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value)}
                    className="w-full glass-strong rounded-lg px-4 py-3 appearance-none cursor-pointer font-bold text-lg bg-transparent border border-white/10 focus:border-primary transition-all outline-none"
                  >
                    <option value={TOKENS.ETH}>🟣 ETH</option>
                    <option value={TOKENS.BTC}>🟠 BTC</option>
                    <option value={TOKENS.USDC}>🔵 USDC</option>
                  </select>
                  <ChevronDown className="absolute right-4 top-1/2 -translate-y-1/2 h-5 w-5 pointer-events-none text-primary" />
                </div>
              </div>

              {/* Validity Select */}
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

            {/* Generate Button */}
            <GradientButton
              size="xl"
              icon={<Zap className="h-6 w-6" />}
              onClick={handleGenerateLink}
              className="w-full"
              disabled={isCreating}
            >
              {isCreating ? 'CREATING LINK...' : 'GENERATE PAYMENT LINK'}
            </GradientButton>

            {!isMerchantActive && (
              <p className="text-center text-sm text-muted-foreground mt-4">
                First time? We'll quickly set up your account.
              </p>
            )}
          </div>
        </motion.div>

        {/* Requests Grid */}
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
            {merchantPayments && (merchantPayments as string[]).length > 0 ? (
              (merchantPayments as string[]).map((paymentId: string, index: number) => (
                <motion.div
                  key={paymentId}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.6 + index * 0.1 }}
                >
                  <PaymentRequestCard paymentId={paymentId} />
                </motion.div>
              ))
            ) : (
              <div className="col-span-full text-center text-muted-foreground py-12">
                <p className="text-xl">No payment requests yet.</p>
                <p>Create your first one above!</p>
              </div>
            )}
          </motion.div>
        </div>
      </main>
    </div>
  );
};

function PaymentRequestCard({ paymentId }: { paymentId: string }) {
  const [copied, setCopied] = useState(false);

  const { data: payment } = useReadContract({
    address: CONTRACTS.PaymentGateway as `0x${string}`,
    abi: PaymentGatewayABI,
    functionName: 'getPayment',
    args: [paymentId],
  })

  if (!payment) return null;

  const paymentData = payment as any;
  const paymentUrl = `${window.location.origin}/pay/${paymentId}`;

  const getTokenSymbol = (tokenAddress: string) => {
    if (tokenAddress === TOKENS.ETH) return 'ETH'
    if (tokenAddress === TOKENS.BTC) return 'BTC'
    if (tokenAddress === TOKENS.USDC) return 'USDC'
    return 'Unknown'
  };

  const currency = getTokenSymbol(paymentData.token) as 'ETH' | 'BTC' | 'USDC';
  const amount = (Number(paymentData.amountUSD) / 1e8).toFixed(2);
  const statusLabels = ['pending', 'paid', 'failed', 'expired', 'refunded'];
  const status = statusLabels[paymentData.status] as 'paid' | 'pending' | 'expired';

  const currencyColors = {
    ETH: "from-primary to-cyan",
    BTC: "from-orange-500 to-yellow-500",
    USDC: "from-blue-500 to-cyan",
  };

  const currencyIcons = {
    ETH: "🟣",
    BTC: "🟠",
    USDC: "🔵",
  };

  const statusConfig = {
    paid: {
      label: "PAID",
      color: "from-accent-lime to-green-500",
      glow: "shadow-[0_0_20px_rgba(132,204,22,0.4)]",
      pulse: false,
    },
    pending: {
      label: "PENDING",
      color: "from-yellow-500 to-orange-500",
      glow: "shadow-[0_0_20px_rgba(251,191,36,0.4)]",
      pulse: true,
    },
    expired: {
      label: "EXPIRED",
      color: "from-red-600 to-red-900",
      glow: "shadow-[0_0_20px_rgba(220,38,38,0.4)]",
      pulse: false,
    },
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(paymentUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
    toast.success("Copied to clipboard!", {
      icon: "📋",
      style: {
        background: "hsl(var(--card))",
        color: "hsl(var(--foreground))",
        border: "1px solid rgba(255,255,255,0.1)",
      },
    });
  };

  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Payment Request',
          text: `Please pay $${amount} via WalletWave`,
          url: paymentUrl,
        });
      } catch (err) {
        handleCopy();
      }
    } else {
      handleCopy();
    }
  };

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
            {statusConfig[status]?.label}
          </motion.div>
          <span className="text-2xl">{currencyIcons[currency]}</span>
        </div>

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

        {paymentData.customer !== '0x0000000000000000000000000000000000000000' && (
          <div className="mb-3 text-sm">
            <span className="text-foreground/60">From: </span>
            <span className="font-mono">{paymentData.customer.slice(0, 6)}...{paymentData.customer.slice(-4)}</span>
          </div>
        )}

        {status === 'pending' && (
          <div className="flex gap-2 mt-4">
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleCopy}
              className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
            >
              {copied ? '✓ Copied!' : '📋 Copy'}
            </motion.button>
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleShare}
              className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
            >
              📤 Share
            </motion.button>
          </div>
        )}
      </div>
    </motion.div>
  );
}

export default RequestMoney;
