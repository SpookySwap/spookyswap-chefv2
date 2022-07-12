import { ethers, run } from "hardhat"

const boo = "0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE"
const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"
const factory = "0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3"
const xboo = "0xa48d959AE2E88f1dAA7D5F611E01908106dE7598"
const usdc = "0x04068da6c83afcfa0e13ba15a6696662335d5b75"
const mcv2 = "0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD"
const mc = "0x2b2929e785374c651a81a63878ab22742656dcdd"

async function main() {
    let accounts = await ethers.getSigners();
    let provider = await ethers.provider
    let tx

    const MCV2 = await ethers.getContractAt("MasterChefV2", mcv2);
    const MC = await ethers.getContractAt("MasterChef", mc);


    let len = await MC.poolLength()
    let newPid = await MCV2.poolInfoAmount()
    let MASTER_PID = 73
    for(let i = 0; i < len; i++) {
        if(i == MASTER_PID) continue
        let info = await MC.poolInfo(i)
        if(info.allocPoint == 0)
            continue

        let newAlloc = info.allocPoint
        if(i == 64 || i == 17 || i == 22) {
            //await MC.set(i, 0)
            continue
        }
        /*if(i == 63 || i == 49)
            newAlloc = 30
        if(i == 70)
            newAlloc = 20
        if(i == 74 || i == 26)
            newAlloc = 50
        if(i == 37)
            newAlloc = 40
        if(i == 42)
            newAlloc = 100*/


        if(i == 0) {
            //await MCV2.set(0, newAlloc, "0x0000000000000000000000000000000000000000", false, true)
        } else {
            await MCV2.add(0, info.lpToken, "0x0000000000000000000000000000000000000000", true)
        }

        //await MC.set(i, 0)
        if(i != 0) console.log("MasterChefV1 pool with PID " + i + " is now on MasterChefV2 with PID " + newPid++ + " and allocPoint " + info.allocPoint)
        else console.log("MasterChefV1 pool with PID " + 0 + " is now on MasterChefV2 with PID " + 0 + " and allocPoint " + info.allocPoint)
    }

    //await MCV2.set(3, 0, "0x0000000000000000000000000000000000000000", false, true) //sd-usdc
    //await MCV2.set(4, 100, "0x0000000000000000000000000000000000000000", false, true) //FTM-sFTMx

    /**/




}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
