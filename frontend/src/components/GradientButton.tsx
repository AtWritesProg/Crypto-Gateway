import { motion, HTMLMotionProps } from "framer-motion";
import { ReactNode } from "react";

interface GradientButtonProps extends Omit<HTMLMotionProps<"button">, "children"> {
  children: ReactNode;
  variant?: "primary" | "secondary" | "accent" | "danger";
  size?: "sm" | "md" | "lg" | "xl";
  icon?: ReactNode;
}

const GradientButton = ({ 
  children, 
  variant = "primary", 
  size = "md", 
  icon,
  className = "",
  ...props 
}: GradientButtonProps) => {
  const variants = {
    primary: "bg-gradient-primary hover:shadow-glow-primary",
    secondary: "bg-gradient-to-r from-secondary to-muted hover:shadow-glow-cyan",
    accent: "bg-gradient-accent hover:shadow-glow-pink",
    danger: "bg-gradient-to-r from-destructive to-accent-pink hover:shadow-glow-pink",
  };

  const sizes = {
    sm: "px-4 py-2 text-sm",
    md: "px-6 py-3 text-base",
    lg: "px-8 py-4 text-lg",
    xl: "px-12 py-6 text-xl",
  };

  return (
    <motion.button
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.95 }}
      className={`
        relative overflow-hidden rounded-xl font-bold
        transition-all duration-300
        ${variants[variant]}
        ${sizes[size]}
        ${className}
      `}
      {...props}
    >
      {/* Shimmer Effect */}
      <motion.div
        className="absolute inset-0 shimmer"
        initial={{ opacity: 0 }}
        whileHover={{ opacity: 1 }}
      />
      
      {/* Content */}
      <span className="relative z-10 flex items-center justify-center gap-2">
        {icon && <span className="animate-pulse-glow">{icon}</span>}
        {children}
      </span>

      {/* Glow Effect */}
      <motion.div
        className="absolute inset-0 opacity-0 blur-xl"
        style={{
          background: variant === "primary" 
            ? "radial-gradient(circle, hsl(var(--primary-glow)) 0%, transparent 70%)"
            : "radial-gradient(circle, hsl(var(--cyan-glow)) 0%, transparent 70%)",
        }}
        whileHover={{ opacity: 0.5 }}
      />
    </motion.button>
  );
};

export default GradientButton;
