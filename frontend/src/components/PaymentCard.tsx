import { motion } from "framer-motion";
import { Copy, Share2, RefreshCw, Check, Clock, X } from "lucide-react";
import { useState } from "react";
import toast from "react-hot-toast";

interface PaymentCardProps {
  amount: string;
  currency: "ETH" | "BTC" | "USDC";
  status: "paid" | "pending" | "expired";
  recipient?: string;
  timeLeft?: string;
  onCopy?: () => void;
  onShare?: () => void;
  onResend?: () => void;
}

const PaymentCard = ({
  amount,
  currency,
  status,
  recipient,
  timeLeft,
  onCopy,
  onShare,
  onResend,
}: PaymentCardProps) => {
  const [isFlipped, setIsFlipped] = useState(false);

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
      icon: Check,
      label: "PAID",
      color: "from-accent-lime to-green-500",
      glow: "shadow-[0_0_20px_hsl(var(--accent-lime)/0.4)]",
      pulse: false,
    },
    pending: {
      icon: Clock,
      label: "PENDING",
      color: "from-yellow-500 to-orange-500",
      glow: "shadow-[0_0_20px_rgba(251,191,36,0.4)]",
      pulse: true,
    },
    expired: {
      icon: X,
      label: "EXPIRED",
      color: "from-destructive to-red-900",
      glow: "shadow-[0_0_20px_hsl(var(--destructive)/0.4)]",
      pulse: false,
    },
  };

  const StatusIcon = statusConfig[status].icon;

  const handleCopy = () => {
    onCopy?.();
    toast.success("Copied to clipboard!", {
      icon: "📋",
      style: {
        background: "hsl(var(--card))",
        color: "hsl(var(--foreground))",
        border: "1px solid rgba(255,255,255,0.1)",
      },
    });
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -5 }}
      className="perspective-1000"
    >
      <motion.div
        className="relative card-3d"
        style={{ transformStyle: "preserve-3d" }}
        animate={{ rotateY: isFlipped ? 180 : 0 }}
        transition={{ duration: 0.6 }}
      >
        {/* Front of Card */}
        <div
          className={`
            glass-strong rounded-2xl p-6 shadow-glass
            border-2 bg-gradient-to-br ${currencyColors[currency]}
            ${statusConfig[status].glow}
            ${isFlipped ? "hidden" : "block"}
          `}
        >
          {/* Status Badge */}
          <div className="flex items-center justify-between mb-4">
            <motion.div
              animate={statusConfig[status].pulse ? { scale: [1, 1.05, 1] } : {}}
              transition={{ duration: 2, repeat: Infinity }}
              className={`
                flex items-center gap-2 px-3 py-1 rounded-full
                bg-gradient-to-r ${statusConfig[status].color}
                text-xs font-bold
              `}
            >
              <StatusIcon className="h-3 w-3" />
              {statusConfig[status].label}
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
          {recipient && (
            <div className="mb-3 text-sm">
              <span className="text-foreground/60">From: </span>
              <span className="font-mono">{recipient}</span>
            </div>
          )}

          {timeLeft && status === "pending" && (
            <motion.div
              animate={{ opacity: [1, 0.5, 1] }}
              transition={{ duration: 1.5, repeat: Infinity }}
              className="mb-3 flex items-center gap-2 text-sm text-yellow-300"
            >
              <Clock className="h-4 w-4" />
              ⏰ {timeLeft}
            </motion.div>
          )}

          {status === "expired" && (
            <div className="mb-3 text-sm text-red-300">
              💀 Link expired
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex gap-2 mt-4">
            {status === "paid" && (
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={handleCopy}
                className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
              >
                <Copy className="h-4 w-4 inline mr-1" />
                Copy
              </motion.button>
            )}
            {status === "pending" && (
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={onShare}
                className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
              >
                <Share2 className="h-4 w-4 inline mr-1" />
                Share
              </motion.button>
            )}
            {status === "expired" && (
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={onResend}
                className="flex-1 glass-strong rounded-lg px-4 py-2 text-sm font-medium hover:bg-white/10 transition-all"
              >
                <RefreshCw className="h-4 w-4 inline mr-1" />
                Resend
              </motion.button>
            )}
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
};

export default PaymentCard;
