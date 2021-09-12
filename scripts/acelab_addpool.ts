import { ethers, run } from "hardhat"

// pass reward per second as argument 0, token address as argument 1 and protocol owner as argument 2
async function main() {
    const acelabAddrMain = "0x2352b745561e7e6FCD03c093cE7220e3e126ace0"
    const myArgs = process.argv.slice(2);
    const AceLab = await ethers.getContractAt("AceLab", acelabAddrMain);
    const now = Math.floor(Date.now() / 1000)
    const day = 86400
    const in2Hours = now + 60 * 60 * 2
    const rewardToken = "0x3A3841f5fa9f2c283EA567d5Aeea3Af022dD2262"
    const protocolOwner = '0x3875DD7A020fFbb50C6Eea481C6CfB43a7BD3b82'
    
    const result = await AceLab.add("10315393518518518", rewardToken, 1631325600, 1631325600 + day * 60, protocolOwner)
    console.log(result)
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });