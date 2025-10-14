import { useState } from "react";
import { motion } from "framer-motion";
import { Bell, Shield, Palette, User } from "lucide-react";
import { useAccount } from 'wagmi';
import AnimatedBackground from "../components/AnimatedBackground";
import GlassNavbar from "../components/GlassNavbar";
import toast, { Toaster } from "react-hot-toast";

const Settings = () => {
  const { address } = useAccount();
  const [notifications, setNotifications] = useState(true);
  const [theme, setTheme] = useState("dark");
  const [defaultCurrency, setDefaultCurrency] = useState("ETH");
  const [defaultValidity, setDefaultValidity] = useState("1800");

  const handleSaveSettings = () => {
    toast.success("Settings saved successfully!", {
      icon: "✅",
      style: {
        background: "hsl(var(--card))",
        color: "hsl(var(--foreground))",
        border: "1px solid rgba(255,255,255,0.1)",
      },
    });
  };

  return (
    <div className="min-h-screen">
      <Toaster position="top-right" />
      <AnimatedBackground />
      <GlassNavbar />

      <main className="container mx-auto px-4 pt-32 pb-16 relative z-10">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <h1 className="text-4xl md:text-5xl font-bold mb-4">
            <span className="gradient-text">Settings</span>
          </h1>
          <p className="text-xl text-muted-foreground">
            Customize your WalletWave experience
          </p>
        </motion.div>

        {/* Settings Sections */}
        <div className="max-w-4xl mx-auto space-y-6 relative">
          {/* Account Section */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="glass-strong rounded-3xl p-8 shadow-elevated border border-white/10"
          >
            <div className="flex items-center gap-3 mb-6">
              <User className="w-6 h-6 text-primary" />
              <h2 className="text-xl font-bold text-foreground">Account</h2>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-muted-foreground mb-2">
                  Connected Wallet
                </label>
                <div className="glass rounded-xl p-4 font-mono text-lg">
                  {address ? `${address.slice(0, 8)}...${address.slice(-6)}` : 'Not connected'}
                </div>
              </div>
            </div>
          </motion.div>

          {/* Preferences Section */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
            className="glass-strong rounded-3xl p-8 shadow-elevated border border-white/10 relative z-10"
          >
            <div className="flex items-center gap-3 mb-6">
              <Palette className="w-6 h-6 text-cyan" />
              <h2 className="text-xl font-bold text-foreground">Preferences</h2>
            </div>

            <div className="space-y-6 relative z-10">
              {/* Default Currency */}
              <div>
                <label className="block text-sm font-medium text-foreground/80 mb-3">
                  Default Currency for Payments
                </label>
                <div className="grid grid-cols-3 gap-3 relative z-20">
                  {['ETH', 'BTC', 'USDC'].map((currency) => (
                    <button
                      key={currency}
                      type="button"
                      onClick={() => {
                        console.log('Currency clicked:', currency);
                        setDefaultCurrency(currency);
                      }}
                      className={`
                        rounded-xl p-4 font-bold text-lg transition-all cursor-pointer relative
                        ${defaultCurrency === currency
                          ? 'bg-gradient-to-r from-primary to-cyan border-2 border-primary text-white'
                          : 'bg-card/50 border border-white/10 hover:border-primary/50 text-foreground'
                        }
                      `}
                      style={{ pointerEvents: 'auto' }}
                    >
                      {currency}
                    </button>
                  ))}
                </div>
              </div>

              {/* Default Validity */}
              <div>
                <label className="block text-sm font-medium text-foreground/80 mb-3">
                  Default Payment Link Validity
                </label>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 relative z-20">
                  {[
                    { value: '300', label: '5 min' },
                    { value: '1800', label: '30 min' },
                    { value: '3600', label: '1 hour' },
                    { value: '86400', label: '24 hours' },
                  ].map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      onClick={() => {
                        console.log('Validity clicked:', option.value);
                        setDefaultValidity(option.value);
                      }}
                      className={`
                        rounded-xl p-4 font-bold transition-all cursor-pointer relative
                        ${defaultValidity === option.value
                          ? 'bg-gradient-to-r from-cyan to-primary border-2 border-cyan text-white'
                          : 'bg-card/50 border border-white/10 hover:border-cyan/50 text-foreground'
                        }
                      `}
                      style={{ pointerEvents: 'auto' }}
                    >
                      {option.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Theme Selection */}
              <div>
                <label className="block text-sm font-medium text-foreground/80 mb-3">
                  Theme
                </label>
                <div className="grid grid-cols-2 gap-3 relative z-20">
                  {['dark', 'light'].map((themeOption) => (
                    <button
                      key={themeOption}
                      type="button"
                      onClick={() => {
                        console.log('Theme clicked:', themeOption);
                        setTheme(themeOption);
                      }}
                      className={`
                        rounded-xl p-4 font-bold capitalize transition-all cursor-pointer relative
                        ${theme === themeOption
                          ? 'bg-gradient-to-r from-accent-pink to-accent-lime border-2 border-accent-pink text-white'
                          : 'bg-card/50 border border-white/10 hover:border-accent-pink/50 text-foreground'
                        }
                      `}
                      style={{ pointerEvents: 'auto' }}
                    >
                      {themeOption}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </motion.div>

          {/* Notifications Section */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="glass-strong rounded-3xl p-8 shadow-elevated border border-white/10"
          >
            <div className="flex items-center gap-3 mb-6">
              <Bell className="w-6 h-6 text-accent-lime" />
              <h2 className="text-xl font-bold text-foreground">Notifications</h2>
            </div>

            <div className="space-y-4">
              <div className="flex items-center justify-between bg-card/50 rounded-xl p-4 border border-white/10">
                <div>
                  <h3 className="font-bold text-lg mb-1">Payment Notifications</h3>
                  <p className="text-sm text-muted-foreground">
                    Get notified when payments are received
                  </p>
                </div>
                <button
                  type="button"
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    console.log('Toggle clicked:', !notifications);
                    setNotifications(!notifications);
                  }}
                  className={`
                    flex-shrink-0 relative w-14 h-7 rounded-full transition-all cursor-pointer
                    ${notifications ? 'bg-gradient-to-r from-primary to-cyan' : 'bg-gray-600'}
                  `}
                >
                  <span
                    className={`
                      absolute top-1 left-1 w-5 h-5 bg-white rounded-full shadow-md transition-transform duration-200 ease-in-out
                      ${notifications ? 'translate-x-7' : 'translate-x-0'}
                    `}
                  />
                </button>
              </div>
            </div>
          </motion.div>

          {/* Security Section */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
            className="glass-strong rounded-3xl p-8 shadow-elevated border border-white/10"
          >
            <div className="flex items-center gap-3 mb-6">
              <Shield className="w-6 h-6 text-accent-pink" />
              <h2 className="text-xl font-bold text-foreground">Security</h2>
            </div>

            <div className="space-y-4">
              <div className="glass rounded-xl p-4">
                <h3 className="font-bold text-lg mb-2">Wallet Connection</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  Your wallet is securely connected via RainbowKit. Always verify transactions before signing.
                </p>
              </div>

              <div className="glass rounded-xl p-4">
                <h3 className="font-bold text-lg mb-2">Smart Contract Security</h3>
                <p className="text-sm text-muted-foreground">
                  All payments are processed through audited smart contracts on the blockchain.
                </p>
              </div>
            </div>
          </motion.div>

          {/* Save Button */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
            className="flex justify-center pt-4"
          >
            <button
              type="button"
              onClick={handleSaveSettings}
              className="
                rounded-2xl px-12 py-4 font-bold text-lg
                bg-gradient-to-r from-primary to-cyan text-white
                hover:scale-105 transition-transform cursor-pointer
                shadow-elevated relative z-20
              "
              style={{ pointerEvents: 'auto' }}
            >
              Save Settings
            </button>
          </motion.div>
        </div>
      </main>
    </div>
  );
};

export default Settings;
