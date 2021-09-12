import { ethers, run } from "hardhat"

async function main() {
    const xboo = "0xa48d959AE2E88f1dAA7D5F611E01908106dE7598"
    const AceLab = await ethers.getContractFactory("AceLab");
    const acelab = await AceLab.deploy(xboo);
    await acelab.deployed()
  
    console.log("AceLab deployed to:", acelab.address);

    await run("verify:verify", {
        address: acelab.address,
        constructorArguments: [xboo],
    })
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });