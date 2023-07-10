import { ethers, run } from "hardhat"

const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"

async function main() {
    const Rewarder = await ethers.getContractFactory("contracts/ComplexRewarderChildless.sol:ComplexRewarder");
    const rewarder = await Rewarder.deploy();
    await rewarder.deployed()

    console.log("rewarder deployed to:", rewarder.address);

    //await rewarder.init("0x1B6382DBDEa11d97f24495C9A90b7c88469134a4" ,1000)


        //const IER = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", "0x70e878aBf7985AE31453D3a914c855fE39120Cc4");
        //await IER.transfer(rewarder.address, "1000000000000000000000")

    //not needed if no changes - bytecode already verified
    await run("verify:verify", {
        address: rewarder.address,
        constructorArguments: [],
    })
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });