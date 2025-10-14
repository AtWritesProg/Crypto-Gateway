import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'WalletWave',
  projectId: '3fbb6bba6f1de962d911bb5b5c9dba88', // Public WalletConnect project ID
  chains: [sepolia],
  ssr: false,
});