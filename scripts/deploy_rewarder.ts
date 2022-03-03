import { ethers, run } from "hardhat"

const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"

async function main() {

    // Edit these before deployment
    const rewardToken = wftm 
    const rewardPerSecond = 0
    // end of edit

    const masterchefv2 = "0x7bC91039C93477515c777e9367Ae49738CC243d0"
    const Rewarder = await ethers.getContractFactory("ComplexRewarder");
    const rewarder = await Rewarder.deploy(rewardToken, rewardPerSecond, masterchefv2);
    await rewarder.deployed()
  
    console.log("rewarder deployed to:", rewarder.address);

    await run("verify:verify", {
        address: rewarder.address,
        constructorArguments: [rewardToken, rewardPerSecond, masterchefv2],
    })
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });