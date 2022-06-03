import { deploy, prepare } from "./utilities"
import { inspect } from 'util'
import { BigNumber } from "ethers"


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
    await prepare(this, ["SpookyFetchHelper"])
    await deploy(this, [["FetchHelper", this.SpookyFetchHelper]])
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
})