import { motion } from "framer-motion";
import { Zap } from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import { ConnectButton } from '@rainbow-me/rainbowkit';

const GlassNavbar = () => {
  const location = useLocation();

  const navItems = [
    { path: "/", label: "Request" },
    { path: "/pay", label: "Pay" },
  ];

  return (
    <motion.nav
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      className="fixed top-0 left-0 right-0 z-50 mx-auto mt-4 max-w-6xl px-4"
    >
      <div className="glass-strong rounded-2xl px-6 py-4 shadow-elevated">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-2">
            <motion.div
              whileHover={{ rotate: 360 }}
              transition={{ duration: 0.6 }}
              className="rounded-xl bg-gradient-primary p-2"
            >
              <Zap className="h-6 w-6 text-primary-foreground" />
            </motion.div>
            <span className="text-2xl font-bold gradient-text">WalletWave</span>
          </Link>

          {/* Nav Links */}
          <div className="hidden md:flex items-center gap-1 bg-card/30 rounded-xl p-1">
            {navItems.map((item) => (
              <Link
                key={item.path}
                to={item.path}
                className="relative px-4 py-2 rounded-lg transition-all"
              >
                {location.pathname === item.path && (
                  <motion.div
                    layoutId="navbar-indicator"
                    className="absolute inset-0 bg-gradient-primary rounded-lg"
                    transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                  />
                )}
                <span className={`relative z-10 font-medium ${
                  location.pathname === item.path ? "text-primary-foreground" : "text-foreground/70 hover:text-foreground"
                }`}>
                  {item.label}
                </span>
              </Link>
            ))}
          </div>

          {/* Wallet Connection */}
          <div className="connect-button-wrapper">
            <ConnectButton />
          </div>
        </div>
      </div>
    </motion.nav>
  );
};

export default GlassNavbar;
