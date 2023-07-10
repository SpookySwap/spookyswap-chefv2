import { ethers, run } from "hardhat"

const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"

async function main() {
    const con = await ethers.getContractFactory("MasterChefV2");
    const mc = await con.attach("0x9C9C920E51778c4ABF727b8Bb223e78132F00aA4");

    //await mc.set(0, 0, "0x450Fa04c1517F1b82238Ed34a473eAB0B7E8bd65", true, true)

    const con2 = await ethers.getContractFactory("contracts/ComplexRewarderChildless.sol:ComplexRewarder");
    const rew = await con2.attach("0x4d4502823D3B4cB00DA897709a33d59586d8C3ae");
    //await rew.init("0x1B6382DBDEa11d97f24495C9A90b7c88469134a4", 9920)
    //await rew.add(10, 7, false)
    //await rew.add(1, 8, true)
    await mc.setBatch([7,8], [3600, 160], ["0x4d4502823D3B4cB00DA897709a33d59586d8C3ae", "0x4d4502823D3B4cB00DA897709a33d59586d8C3ae"], [true, true], true)






    //not needed if no changes - bytecode already verified
    /*await run("verify:verify", {
        address: rewarder.address,
        constructorArguments: [],
    })*/
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });