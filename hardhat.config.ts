import { task, types } from "hardhat/config"
import "dotenv/config"
import "ethers"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-solhint"
import "@nomiclabs/hardhat-ethers"
import "hardhat-abi-exporter"
import "solidity-coverage"
import "hardhat-spdx-license-identifier"
import { HardhatUserConfig } from "hardhat/types"
import "hardhat-gas-reporter"

const MASTER_PID = 73
const MCV1 = "0x2b2929E785374c651a81A63878Ab22742656DcDd"
const MCV2 = "0x7bC91039C93477515c777e9367Ae49738CC243d0"

task("addpool", "Adds pool to MCv2").addParam("allocPoint", "Amount of points to allocate to the new pool", undefined, types.int).addParam("lpToken", "Address of the LP tokens for the farm").addOptionalParam("rewarder", "Address of the rewardercontract for the farm").addOptionalParam("update", "true if massUpdateAllPools should be called", false, types.boolean).addParam("sleep", "Time in seconds to sleep between adding and setting up the pool", undefined, types.int).setAction(async (taskArgs, hre) => {
    const wait = (milliseconds) => {
      return new Promise(resolve => setTimeout(resolve, milliseconds))
    }

    let allocPoint, lpToken, tx
    allocPoint = hre.ethers.utils.parseUnits((taskArgs.allocPoint).toString(), 0)
    let rewarder = taskArgs.rewarder == undefined ? "0x0000000000000000000000000000000000000000" : taskArgs.rewarder

    try {
        lpToken = hre.ethers.utils.getAddress(taskArgs.lpToken)
    } catch {
        console.log("ERROR: LP token address not valid")
        return
    }

    //set this manually here when needed
    let overwrite = true

    let MCv1 = await hre.ethers.getContractAt("MasterChef", MCV1)
    let MCv2 = await hre.ethers.getContractAt("MasterChefV2", MCV2)

    console.log("Adding pool...")
    tx = await MCv2.add(0, lpToken, rewarder, taskArgs.update)
    await tx.wait();

    console.log("Sleeping for " + taskArgs.sleep + " seconds...")
    await wait(taskArgs.sleep * 1000)

    console.log("Adjusting MCv1 allocation...")
    let newAlloc = Number(hre.ethers.utils.formatUnits((await MCv1.poolInfo(MASTER_PID)).allocPoint, 0)) + Number(taskArgs.allocPoint)
    tx = await MCv1.set(MASTER_PID, newAlloc)
    await tx.wait();

    console.log("Setting new MCv2 pool allocation...")
    let pid = (await MCv2.poolInfoAmount()) - 1
    tx = await MCv2.set(pid, allocPoint, rewarder, overwrite, taskArgs.update)
    await tx.wait();
});

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const accounts = {
  mnemonic: process.env.MNEMONIC || "test test test test test test test test test test test junk",
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  mocha: {
    timeout: 20000,
  },
  etherscan: {
    apiKey: process.env.FTMSCAN_API_KEY
  },
  networks: {
    hardhat: {
      accounts,
      /*forking: {
        url: "https://rpc.ftm.tools",
        blockNumber: 34725366,
      },*/
      chainId: 250,
    },
    localhost: {
      accounts,
      gasPrice: 20000000000,
    },
    fantom: {
      url: "https://rpc.ankr.com/fantom",
      accounts,
      chainId: 250,
      gasPrice: 1000000000000,
    },
    "fantom-testnet": {
      url: "https://rpc.testnet.fantom.network",
      accounts,
      chainId: 4002,
      gasMultiplier: 2,
    },
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      },
    ],
  },
}
export default config
