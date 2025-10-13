import { motion } from "framer-motion";
import { useState } from "react";

interface AmountInputProps {
  value: string;
  onChange: (value: string) => void;
  currency?: string;
}

const AmountInput = ({ value, onChange, currency = "USD" }: AmountInputProps) => {
  const [isFocused, setIsFocused] = useState(false);

  return (
    <div className="relative">
      <motion.div
        animate={{
          scale: isFocused ? 1.02 : 1,
        }}
        className={`
          glass-strong rounded-2xl p-8 border-2 transition-all duration-300
          ${isFocused ? "border-primary shadow-glow-primary" : "border-white/10"}
        `}
      >
        <label className="block text-sm font-medium text-muted-foreground mb-2 uppercase tracking-wider">
          How much?
        </label>
        
        <div className="flex items-center gap-3">
          <motion.span
            animate={{
              scale: value ? [1, 1.2, 1] : 1,
            }}
            className="text-5xl"
          >
            💵
          </motion.span>
          
          <div className="flex-1 relative">
            <span className="absolute left-0 top-1/2 -translate-y-1/2 text-4xl font-bold text-primary">
              $
            </span>
            <input
              type="number"
              value={value}
              onChange={(e) => onChange(e.target.value)}
              onFocus={() => setIsFocused(true)}
              onBlur={() => setIsFocused(false)}
              placeholder="0.00"
              className="
                w-full bg-transparent border-0 outline-none
                text-5xl font-bold pl-8
                text-foreground placeholder:text-muted-foreground/30
                [-moz-appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none
              "
            />
          </div>

          <motion.span
            animate={{
              opacity: value ? 1 : 0.3,
              scale: value ? 1 : 0.9,
            }}
            className="text-2xl font-bold gradient-text"
          >
            {currency}
          </motion.span>
        </div>

        {value && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-4 text-sm text-muted-foreground"
          >
            ≈ {(parseFloat(value) / 4000).toFixed(4)} ETH
          </motion.div>
        )}

        {/* Glow Effect on Focus */}
        {isFocused && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="absolute inset-0 -z-10 blur-2xl rounded-2xl bg-gradient-primary opacity-20"
          />
        )}
      </motion.div>
    </div>
  );
};

export default AmountInput;
