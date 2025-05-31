import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from 'hardhat/types/config'

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.24',
  },
  gasReporter: {
    enabled: true,
  },
}

export default config
