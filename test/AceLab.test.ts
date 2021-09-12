
import { ethers } from "hardhat";
import { expect } from "chai";
import { advanceTimeAndBlock, latest } from "./utilities/time"

describe("AceLab", function () {
  before(async function () {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.carol = this.signers[2]
    this.dev = this.signers[3]
    this.minter = this.signers[4]
    this.globalStart = 1635097600

    this.AceLab = await ethers.getContractFactory("AceLab", this.minter)
    this.xBOO = await ethers.getContractFactory("ERC20Mock", this.minter)
    this.ERC20Mock = await ethers.getContractFactory("ERC20Mock", this.minter)
  })

  context("With ERC/LP token added to the field", function () {
    beforeEach(async function () {
      this.rew = await this.ERC20Mock.deploy("Reward1", "rew", "100000000000")
      await this.rew.deployed()

      this.rew2 = await this.ERC20Mock.deploy("Reward2", "rew2", "100000000000")
      await this.rew2.deployed()

      this.xboo = await this.xBOO.deploy("xboo", "xboo", "100000000000")
      await this.xboo.deployed()

      await this.xboo.transfer(this.alice.address, "1000")

      await this.xboo.transfer(this.bob.address, "1000")

      await this.xboo.transfer(this.carol.address, "1000")

      this.chef = await this.AceLab.deploy(this.xboo.address)

      await this.chef.deployed()

      // await ethers.provider.send("evm_setNextBlockTimestamp", [this.globalStart])
      // await advanceBlock()
    })

    it("should allow emergency withdraw", async function () {
      const now = await latest()
      await this.chef.add("1", this.rew.address, now, (now + 1000).toString(), this.dev.address)

      await this.xboo.connect(this.bob).approve(this.chef.address, "1000")

      await this.chef.connect(this.bob).deposit(0, "100")

      expect(await this.xboo.balanceOf(this.bob.address)).to.equal("900")

      await this.chef.connect(this.bob).emergencyWithdraw(0)

      expect(await this.xboo.balanceOf(this.bob.address)).to.equal("1000")
    })

    it("should only allow withdrawing non xboo or reward tokens, or reward to protocol dev", async function () {
      const now = await latest()
      await this.chef.add("1", this.rew.address, now.toString(), (now + 1000).toString(), this.dev.address)
      await this.rew.transfer(this.chef.address, "100")
      await this.rew2.transfer(this.chef.address, "100")

      await this.xboo.connect(this.bob).approve(this.chef.address, "1000")

      await this.chef.connect(this.bob).deposit(0, "100")

      // make sure only tokens not set to be a reward token or xboo can be withdrawn
      expect(await this.xboo.balanceOf(this.chef.address)).to.equal("100")
      expect(await this.rew.balanceOf(this.chef.address)).to.equal("100")
      expect(await this.rew2.balanceOf(this.chef.address)).to.equal("100")

      await expect(this.chef.recoverWrongTokens(this.xboo.address)).to.be.revertedWith("recoverWrongTokens: Cannot be xboo")
      await expect(this.chef.recoverWrongTokens(this.rew.address)).to.be.revertedWith("checkForToken: reward token provided")

      expect(await this.chef.recoverWrongTokens(this.rew2.address))

      expect(await this.rew2.balanceOf(this.chef.address)).to.equal("0")

      // check withdrawing reward token to set protocol developer address
      expect(await this.rew.balanceOf(this.dev.address)).to.equal("0")

      expect(await this.chef.emergencyRewardWithdraw("0", "100"))

      expect(await this.rew.balanceOf(this.chef.address)).to.equal("0")
      expect(await this.rew.balanceOf(this.dev.address)).to.equal("100")
    })

    it("should only allow 100 deposited once set, until 2 days pass", async function () {
      const now = await latest()
      await this.chef.add("1", this.rew.address, now.toString(), (now + 1000).toString(), this.dev.address)
      await this.rew.transfer(this.chef.address, "100")

      await this.xboo.connect(this.bob).approve(this.chef.address, "1000")

      await this.chef.connect(this.bob).deposit(0, "200")
      await this.chef.connect(this.bob).withdraw(0, "200")

      await this.chef.changeUserLimit("100")

      await expect(this.chef.connect(this.bob).deposit(0, "200")).to.be.revertedWith("deposit: user has hit deposit cap")

      await this.chef.connect(this.bob).deposit(0, "100")

      await advanceTimeAndBlock(86500*2)

      await this.chef.connect(this.bob).deposit(0, "100")
      expect(await this.xboo.balanceOf(this.chef.address)).to.equal("200")

    })

    it("should give out rewards only after farming time and before farming end time", async function () {
      let now = await latest()
      await this.chef.add("1", this.rew.address, (now + 100).toString(), (now + 150).toString(), this.dev.address)
      await this.rew.transfer(this.chef.address, "1000")

      await this.xboo.connect(this.bob).approve(this.chef.address, "1000")
      await this.chef.connect(this.bob).deposit(0, "100")
      await advanceTimeAndBlock(90)

      await this.chef.connect(this.bob).deposit(0, "0") // 90 seconds
      expect(await this.rew.balanceOf(this.bob.address)).to.equal("0")
      await advanceTimeAndBlock(9)

      await this.chef.connect(this.bob).deposit(0, "0") // 100 seconds
      expect(await this.rew.balanceOf(this.bob.address)).to.equal("0")
      await advanceTimeAndBlock(51)

      await this.chef.connect(this.bob).deposit(0, "0") // 150 seconds 
      expect(await this.rew.balanceOf(this.bob.address)).to.equal("50")
      await advanceTimeAndBlock(100)

      await this.chef.connect(this.bob).deposit(0, "0") // 250 seconds 
      expect(await this.rew.balanceOf(this.bob.address)).to.equal("50")
      expect(await this.rew.balanceOf(this.chef.address)).to.equal("950")

      await this.chef.changeEndTime("0", "150")
      await advanceTimeAndBlock(200)

      await this.chef.connect(this.bob).deposit(0, "0") // 350 seconds 
      expect(await this.rew.balanceOf(this.bob.address)).to.equal("99")
      expect(await this.rew.balanceOf(this.chef.address)).to.equal("901")
      
    })

    it("should distribute rewards properly for each staker", async function () {
      let now = await latest()
      await this.chef.add("1", this.rew.address, now.toString(), (now + 700).toString(), this.dev.address)
      await this.rew.transfer(this.chef.address, "10000")

      await this.xboo.connect(this.alice).approve(this.chef.address, "1000", {
        from: this.alice.address,
      })
      await this.xboo.connect(this.bob).approve(this.chef.address, "1000", {
        from: this.bob.address,
      })
      await this.xboo.connect(this.carol).approve(this.chef.address, "1000", {
        from: this.carol.address,
      })
      // Alice deposits 10 xboo at time 0
      await this.chef.connect(this.alice).deposit(0, "10", { from: this.alice.address })
      // Bob deposits 20 xboo at time 1000
      await advanceTimeAndBlock(100)

      await this.chef.connect(this.bob).deposit(0, "20", { from: this.bob.address })
      // Carol deposits 30 xboo at time 2000
      await advanceTimeAndBlock(100)
      await this.chef.connect(this.carol).deposit(0, "30", { from: this.carol.address })
      // Alice deposits 10 more LPs at time 3000. At this point:
      //   Alice should have: 1000 + 1/3*1000 + 1/6*1000 = 1500
      await advanceTimeAndBlock(100)

      await this.chef.connect(this.alice).deposit(0, "10", { from: this.alice.address })

      // Bob withdraws 5 LPs at time 400. At this point:
      await advanceTimeAndBlock(100)

      await this.chef.connect(this.bob).withdraw(0, "5", { from: this.bob.address })

      // Alice withdraws 20 LPs at time 5000.
      // Bob withdraws 15 LPs at time 6000.
      // Carol withdraws 30 LPs at time 7000.
      await advanceTimeAndBlock(100)

      await this.chef.connect(this.alice).withdraw(0, "20", { from: this.alice.address })
      await advanceTimeAndBlock(100)

      await this.chef.connect(this.bob).withdraw(0, "15", { from: this.bob.address })
      await advanceTimeAndBlock(110)

      await this.chef.connect(this.carol).withdraw(0, "30", { from: this.carol.address })

      // Alice should have: 1500 + 2/7*1000 + 2/6.5*1000 = 209
      expect(await this.rew.balanceOf(this.alice.address)).to.equal("210")
      // Bob should have: 1285 + 1.5/6.5*1000 + 1.5/4.5*1000 = 185
      expect(await this.rew.balanceOf(this.bob.address)).to.equal("185")
      // Carol should have: 3/6*1000 + 3/7*1000 + 3/6.5*1000 + 3/4.5*1000 + 1000 = 305
      expect(await this.rew.balanceOf(this.carol.address)).to.equal("305")
      // All of them should have 1000 LPs back.
      expect(await this.xboo.balanceOf(this.alice.address)).to.equal("1000")
      expect(await this.xboo.balanceOf(this.bob.address)).to.equal("1000")
      expect(await this.xboo.balanceOf(this.carol.address)).to.equal("1000")
    })

    it("should handle multiple pools", async function () {
      let now = await latest()
      await this.chef.add("1", this.rew.address, (now + 10).toString(), (now + 110).toString(), this.dev.address)
      await this.chef.add("2", this.rew2.address, (now + 10).toString(), (now + 110).toString(), this.dev.address)
      await this.rew.transfer(this.chef.address, "10000")
      await this.rew2.transfer(this.chef.address, "10000")

      await this.xboo.connect(this.alice).approve(this.chef.address, "1000", {
        from: this.alice.address,
      })

      await this.chef.connect(this.alice).deposit(0, "10", { from: this.alice.address })
      await advanceTimeAndBlock(59) // time 60

      await this.chef.connect(this.alice).deposit(1, "10", { from: this.alice.address })
      await advanceTimeAndBlock(100) // time 160 

      await this.chef.connect(this.alice).deposit(0, 0, { from: this.alice.address })
      await this.chef.connect(this.alice).deposit(1, 0, { from: this.alice.address })
      expect(await this.rew.balanceOf(this.alice.address)).to.equal("100")
      expect(await this.rew2.balanceOf(this.alice.address)).to.equal("100")

    })

  })
})