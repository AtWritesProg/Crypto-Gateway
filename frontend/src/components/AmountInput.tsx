import { motion } from "framer-motion";
import { useState } from "react";

interface AmountInputProps {
  value: string;
  onChange: (value: string) => void;
  currency?: string;
}

const AmountInput = ({ value, onChange, currency = "USD" }: AmountInputProps) => {
  return (
    <div className="relative">
      <div className="glass-strong rounded-2xl p-8 border-2 border-white/10">
        <label className="block text-sm font-medium text-muted-foreground mb-2 uppercase tracking-wider">
          How much?
        </label>

        <div className="flex items-center gap-3">
          <div className="flex-1 relative">
            <span className="absolute left-0 top-1/2 -translate-y-1/2 text-4xl font-bold text-primary">
              $
            </span>
            <input
              type="number"
              value={value}
              onChange={(e) => onChange(e.target.value)}
              placeholder="0.00"
              className="
                w-full bg-transparent border-0 outline-none
                text-5xl font-bold pl-8
                text-foreground placeholder:text-muted-foreground/30
                [-moz-appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none
              "
            />
          </div>

          <span className="text-2xl font-bold gradient-text opacity-60">
            {currency}
          </span>
        </div>

        {value && (
          <div className="mt-4 text-sm text-muted-foreground">
            ≈ {(parseFloat(value) / 4000).toFixed(4)} ETH
          </div>
        )}
      </div>
    </div>
  );
};

export default AmountInput;
