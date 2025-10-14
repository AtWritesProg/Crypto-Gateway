import { Routes, Route } from 'react-router-dom'
import RequestMoney from './pages/RequestMoney'
import SimplePaymentPage from './components/SimplePaymentPage'
import Settings from './pages/Settings'
import './App.css'

function App() {
  return (
    <Routes>
      <Route path="/" element={<RequestMoney />} />
      <Route path="/pay" element={<SimplePaymentPage />} />
      <Route path="/pay/:paymentId" element={<SimplePaymentPage />} />
      <Route path="/settings" element={<Settings />} />
    </Routes>
  )
}

export default App
