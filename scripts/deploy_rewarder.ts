import { ethers, run } from "hardhat"

const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"

async function main() {
    const Rewarder = await ethers.getContractFactory("ComplexRewarder");
    const rewarder = await Rewarder.deploy();
    await rewarder.deployed()
  
    console.log("rewarder deployed to:", rewarder.address);

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