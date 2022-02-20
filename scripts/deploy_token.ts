import { ethers, run } from "hardhat"

async function main() {
    const masterchefv2 = ""
    const Token = await ethers.getContractFactory("ERC20Mock");
    const token = await Token.deploy("dummy", "dummy", 1000);
    await token.deployed()
  
    console.log("dummy deployed to:", token.address);

    await run("verify:verify", {
        address: token.address,
        constructorArguments: ["dummy", "dummy", 1000],
    })

    let tx = await token.approve(masterchefv2, 1000)
    console.log(tx)
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });