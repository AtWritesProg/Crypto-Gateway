import { Routes, Route } from 'react-router-dom'
import SimpleRequestPage from './components/SimpleRequestPage'
import SimplePaymentPage from './components/SimplePaymentPage'
import './App.css'

function App() {
  return (
    <Routes>
      <Route path="/" element={<SimpleRequestPage />} />
      <Route path="/pay" element={<SimplePaymentPage />} />
      <Route path="/pay/:paymentId" element={<SimplePaymentPage />} />
    </Routes>
  )
}

export default App
