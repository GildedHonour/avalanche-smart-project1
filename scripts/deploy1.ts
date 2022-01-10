import {
  Contract,
  ContractFactory
} from "ethers"

import { ethers } from "hardhat"

const main = async(): Promise<any> => {
  const Coin: ContractFactory = await ethers.getContractFactory("ILTSToken")
  const coin: Contract = await Coin.deploy()

  await coin.deployed()
  console.log(`Coin deployed to: ${coin.address}`)

  const VestingCoin: ContractFactory = await ethers.getContractFactory("Vesting")
  const vestingCoin: Contract = await VestingCoin.deploy(coin.address)
  console.log(`Vesting coin deployed to: ${vestingCoin.address}`)
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error)
  process.exit(1)
})
