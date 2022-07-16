import { deploy, getBigNumber, prepare } from "./utilities"
import { inspect } from 'util'
import { BigNumber } from "ethers"
import { ethers, network } from "hardhat"


const addresses = {
  mcv3: '0xDF5e820568BAEE4817e9f6d2c10385B61e45Be6B',
  mcv3Owner: '0x4a14507784fecb4bbeadf5e8d34dc5cf5b7f22a7'
}

const tokens = {
  boo: '0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE',
  wftm: '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
  fusdt: '0x049d68029688eAbF473097a2fC38ef61633A3C7A',
  usdc: '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75',
  dai: '0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E',
  dei: '0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3',
  deus: '0xDE5ed76E7c05eC5e4572CfC88d1ACEA165109E44',
  sd: '0x412a13C109aC30f0dB80AD3Bd1DeFd5D0A6c0Ac6',
  sftmx: '0xd7028092c830b5C8FcE061Af2E593413EbbC1fc1',
}

interface FarmConfig {
  pid: number
  version: number
  lpSymbol: string
  lp: string
  token: string
  quoteToken: string
  rewardTokens?: string[]
  stakedUser?: string
  unstakedUser: string
}

const Farms: FarmConfig[] = [
  {
    pid: 0,
    version: 1,
    lpSymbol: 'FTM-BOO',
    lp: '0xEc7178F4C41f346b2721907F5cF7628E388A7a58',
    token: tokens.wftm,
    quoteToken: tokens.boo,
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },
  {
    pid: 1,
    version: 1,
    lpSymbol: 'fUSDT-FTM',
    lp: '0x5965E53aa80a0bcF1CD6dbDd72e6A9b2AA047410',
    token: tokens.fusdt,
    quoteToken: tokens.wftm,
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },
  {
    pid: 2,
    version: 1,
    lpSymbol: 'USDC-FTM',
    lp: '0x2b4c76d0dc16be1c31d4c1dc53bf9b45987fc75c',
    token: tokens.usdc,
    quoteToken: tokens.wftm,
    stakedUser: '0xf5d76A33953365e4f074AE58e34C39A52B8E9671',
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },
  {
    pid: 3,
    version: 1,
    lpSymbol: 'FTM-DAI',
    lp: '0xe120ffBDA0d14f3Bb6d6053E90E63c572A66a428',
    token: tokens.wftm,
    quoteToken: tokens.dai,
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },

  {
    pid: 1,
    version: 2,
    lpSymbol: 'USDC-DEI',
    lp: '0xD343b8361Ce32A9e570C1fC8D4244d32848df88B',
    token: tokens.usdc,
    quoteToken: tokens.dei,
    rewardTokens: [tokens.deus],
    stakedUser: '0x4cc45a80a57e60b28f5761aa6d705580ab329faf',
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },
  {
    pid: 2,
    version: 2,
    lpSymbol: 'FTM-DEUS',
    lp: '0xaF918eF5b9f33231764A5557881E6D3e5277d456',
    token: tokens.wftm,
    quoteToken: tokens.deus,
    rewardTokens: [tokens.deus],
    stakedUser: '0x7549b90F096ac4f03761430cC8BF38219Fc57C73',
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },
  {
    pid: 3,
    version: 2,
    lpSymbol: 'USDC-SD',
    lp: '0xeaa3C87135eE1140E1D60FC8B577fbb41163D840',
    token: tokens.usdc,
    quoteToken: tokens.sd,
    rewardTokens: [tokens.sd],
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },
  {
    pid: 4,
    version: 2,
    lpSymbol: 'FTM-sFTMx',
    lp: '0xE67980fc955FECfDA8A92BbbFBCc9f0C4bE60A9A',
    token: tokens.wftm,
    quoteToken: tokens.sftmx,
    rewardTokens: [tokens.sd],
    unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
  },
]

const deepKeyify = (arr) => {
  return JSON.parse(JSON.stringify(arr, keyifier))
}

const keyifier = (key, value) => {
  if (typeof value === 'object' && value.type && value.type === 'BigNumber') {
    return `BigNumber (value: ${BigNumber.from(value.hex).toString()})`
  }

  if (!Array.isArray(value)) return value
  
  const textKeys = Object.keys(value).filter((k) => isNaN(Number(k)))
  if (textKeys.length === 0) return value

  const ret = {}
  textKeys.forEach((k) => {
    ret[k] = value[k]
  })
  return ret
}

const consoleLog = (logs) => {
  console.log(inspect(logs, {showHidden: false, depth: null, colors: true}))}


describe.only("FetchHelper", function() {
  before(async function() {
    await prepare(this, ["SpookyFetchHelper", "ERC20Mock", "ComplexRewarder"])

    await deploy(this, [
      // Deploy Fetch Helper
      ["FetchHelper", this.SpookyFetchHelper],

      // Deploy Dummy + Reward token token
      ["dummyLP", this.ERC20Mock, ["DummyLP", "DummyLP", getBigNumber(10)]],
      ["dummyRewardToken1", this.ERC20Mock, ["dummyReward1", "dummyReward1", getBigNumber(10)]],
      ["dummyRewardToken2", this.ERC20Mock, ["dummyReward2", "dummyReward2", getBigNumber(10)]],
      ["dummyRewardToken3", this.ERC20Mock, ["dummyReward3", "dummyReward3", getBigNumber(10)]],
    ])

    // Create complex rewarder, add 2 child rewarders
    await deploy(this, [
      ["complexRewarder", this.ComplexRewarder, [this.dummyRewardToken1.address, getBigNumber(3, 16), addresses.mcv3]]
    ])
    await this.complexRewarder.createChild(this.dummyRewardToken2.address, getBigNumber(2, 16))
    await this.complexRewarder.createChild(this.dummyRewardToken3.address, getBigNumber(1, 16))

    // Send Tokens to complex + child rewarders
    await this.dummyRewardToken1.transfer(this.complexRewarder.address, getBigNumber(10))
    const [child1Address, child2Address] = await this.complexRewarder.getChildrenRewarders()
    this.childRewarder1 = await ethers.getContractAt("ChildRewarder", child1Address)
    this.childRewarder2 = await ethers.getContractAt("ChildRewarder", child2Address)
    await this.dummyRewardToken2.transfer(this.childRewarder1.address, getBigNumber(10))
    await this.dummyRewardToken3.transfer(this.childRewarder2.address, getBigNumber(10))

    // Get constants
    this.chefv3 = await ethers.getContractAt("MasterChefV2", addresses.mcv3)

    // const chefReal = await this.chefv3.owner()
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [addresses.mcv3Owner],
    });
    const chefOwner = await ethers.getSigner(addresses.mcv3Owner)
    const dummyLpPid = await this.chefv3.poolLength()

    // Add Dummy LP token pool
    await this.chefv3.connect(chefOwner).add(100, this.dummyLP.address, this.complexRewarder.address, true)
    await this.complexRewarder.add(100, dummyLpPid, true)
    await this.childRewarder1.add(100, dummyLpPid, true)
    await this.childRewarder2.add(100, dummyLpPid, true)
    
    // Stake Alice in Dummy LP pool
    await this.dummyLP.approve(this.chefv3.address, getBigNumber(10))
    await this.chefv3["deposit(uint256,uint256)"](dummyLpPid, getBigNumber(5))

    // Mine 50 seconds
    const block = await ethers.provider.getBlock('latest')
    const timestamp = block.timestamp
    await network.provider.send('evm_setNextBlockTimestamp', [timestamp + 50])
    await network.provider.send('evm_mine')

    // Add Dummy LP pool to farms list
    this.complexRewardedFarm = {
      pid: dummyLpPid,
      version: 2,
      lpSymbol: 'DUMMY-LP',
      lp: this.dummyLP.address,
      token: '',
      quoteToken: '',
      rewardTokens: [this.dummyRewardToken1.address, this.dummyRewardToken2.address, this.dummyRewardToken3.address],
      stakedUser: this.alice.address,
      unstakedUser: '0x3a7679E3662bC7c2EB2B1E71FA221dA430c6f64B',
    } as FarmConfig
  })

  describe("Fetching Lp", async function() {
    it("Fetching LP data should succeed", async function() {

      for (let i = 0; i < Farms.length; i++) {
        const farm = Farms[i]
        const lpData = await this.FetchHelper.fetchLpData(farm.lp, farm.token, farm.quoteToken, farm.version)
        consoleLog({
          [farm.lpSymbol]: deepKeyify(lpData)
        })
      }

    })
  })

  describe("Fetching Farms", async function() {
    it("Fetching Farm data should succeed", async function() {

      for (let i = 0; i < Farms.length; i++) {
        const farm = Farms[i]
        const farmData = await this.FetchHelper.fetchFarmData(farm.pid, farm.version)
        consoleLog({
          [farm.lpSymbol]: deepKeyify(farmData)
        })
      }

    })
  })

  describe("Fetching User Lp", async function() {
    it("Fetching LP data should succeed", async function() {

      for (let i = 0; i < Farms.length; i++) {
        const farm = Farms[i]
        if (farm.stakedUser) {
          const stakedUserLpData = await this.FetchHelper.fetchUserLpData(farm.stakedUser, farm.lp, farm.version)
          consoleLog({
            [`${farm.lpSymbol}-staked`]: deepKeyify(stakedUserLpData),
          })
        }
        const unstakedUserLpData = await this.FetchHelper.fetchUserLpData(farm.unstakedUser, farm.lp, farm.version)
        consoleLog({
          [`${farm.lpSymbol}-unstaked`]: deepKeyify(unstakedUserLpData),
        })
      }

    })
  })

  describe("Fetching User Farms", async function() {
    it("Fetching Farm data should succeed", async function() {

      for (let i = 0; i < Farms.length; i++) {
        const farm = Farms[i]
        if (farm.stakedUser) {
          const stakedUserFarmData = await this.FetchHelper.fetchUserFarmData(farm.stakedUser, farm.pid, farm.version)
          consoleLog({
            [`${farm.lpSymbol}-staked`]: deepKeyify(stakedUserFarmData),
          })
        }
        const unstakedUserFarmData = await this.FetchHelper.fetchUserFarmData(farm.unstakedUser, farm.pid, farm.version)
        consoleLog({
          [`${farm.lpSymbol}-unstaked`]: deepKeyify(unstakedUserFarmData),
        })
      }

    })
  })

  describe("Complex + Child Rewarder Farm", async function() {
    it("Fetching Farm data should succeed", async function() {
      const farmData = await this.FetchHelper.fetchFarmData(this.complexRewardedFarm.pid, this.complexRewardedFarm.version)
      consoleLog({
        [this.complexRewardedFarm.lpSymbol]: deepKeyify(farmData)
      })
    })
    it("Fetching Farm User data should succeed", async function() {
      const stakedUserFarmData = await this.FetchHelper.fetchUserFarmData(this.complexRewardedFarm.stakedUser, this.complexRewardedFarm.pid, this.complexRewardedFarm.version)
      consoleLog({
        [`${this.complexRewardedFarm.lpSymbol}-staked`]: deepKeyify(stakedUserFarmData),
      })
      const unstakedUserFarmData = await this.FetchHelper.fetchUserFarmData(this.complexRewardedFarm.unstakedUser, this.complexRewardedFarm.pid, this.complexRewardedFarm.version)
      consoleLog({
        [`${this.complexRewardedFarm.lpSymbol}-unstaked`]: deepKeyify(unstakedUserFarmData),
      })
    })
  })
})