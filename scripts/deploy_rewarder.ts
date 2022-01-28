import { ethers, run } from "hardhat"

async function main() {

    // Edit these before deployment
    const rewardToken = "0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE"
    const rewardPerSecond = 111111111111111111
    // end of edit

    const masterchef = "0x2b2929E785374c651a81A63878Ab22742656DcDd"
    const Mcv2 = await ethers.getContractFactory("MasterChefV2");
    const mcv2 = await Mcv2.deploy(rewardToken, rewardPerSecond, masterchef);
    await mcv2.deployed()
  
    console.log("mcv2 deployed to:", mcv2.address);

    await run("verify:verify", {
        address: mcv2.address,
        constructorArguments: [masterchef, rewardToken, rewardPerSecond],
    })
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });