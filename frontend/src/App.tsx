import { Routes, Route, Link } from 'react-router-dom'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import MerchantDashboard from './components/MerchantDashboard'
import PaymentPage from './components/PaymentPage'
import './App.css'

function App() {
  return (
    <div className="app">
      <header className="header">
        <div className="container">
          <h1 className="logo">💳 WalletWave</h1>
          <nav className="nav">
            <Link to="/">Merchant Dashboard</Link>
            <Link to="/pay">Make Payment</Link>
          </nav>
          <ConnectButton />
        </div>
      </header>

      <main className="main">
        <Routes>
          <Route path="/" element={<MerchantDashboard />} />
          <Route path="/pay" element={<PaymentPage />} />
          <Route path="/pay/:paymentId" element={<PaymentPage />} />
        </Routes>
      </main>

      <footer className="footer">
        <p>WalletWave - Crypto Payment Gateway on Sepolia Testnet</p>
      </footer>
    </div>
  )
}

export default App
