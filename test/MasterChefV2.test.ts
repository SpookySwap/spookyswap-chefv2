import { ADDRESS_ZERO, advanceBlock, advanceBlockTo, deploy, getBigNumber, prepare } from "./utilities"
import { assert, expect } from "chai"

describe("MasterChefV2", function () {
  before(async function () {
    await prepare(this, ["MasterChef", "SpookyToken", "ERC20Mock", "MasterChefV2", "ComplexRewarderTime"])
    //await deploy(this, [["brokenRewarder", this.RewarderBrokenMock]])
  })

  beforeEach(async function () {
    await deploy(this, [["Boo", this.SpookyToken]])

    await deploy(this, [
      ["lp", this.ERC20Mock, ["LP Token", "LPT", getBigNumber(10)]],
      ["dummy", this.ERC20Mock, ["Dummy", "DummyT", getBigNumber(10)]],
      ["chef", this.MasterChef, [this.Boo.address, this.bob.address, getBigNumber(100), getBigNumber(0)]],
    ])

    await this.Boo.transferOwnership(this.chef.address)
    await this.chef.add(100, this.lp.address)
    await this.chef.add(100, this.dummy.address)
    await this.lp.approve(this.chef.address, getBigNumber(10))
    await this.chef.deposit(0, getBigNumber(10))

    await deploy(this, [
      ["chef2", this.MasterChefV2, [this.chef.address, this.Boo.address, 1]],
      ["rlp", this.ERC20Mock, ["LP", "rLPT", getBigNumber(10)]],
      ["r", this.ERC20Mock, ["Reward", "RewardT", getBigNumber(100000)]],
    ])
    await deploy(this, [["rewarder", this.ComplexRewarderTime, [this.r.address, getBigNumber(1), this.chef2.address]]])
    await this.dummy.approve(this.chef2.address, getBigNumber(10))
    await this.chef2.init(this.dummy.address)
    await this.rlp.transfer(this.bob.address, getBigNumber(1))

    //await this.rewarder. //NEED TO ADD REWARDS TO REWARDER HERE
  })

  describe("Init", function () {
    it("Balance of dummyToken should be 0 after init(), repeated execution should fail", async function () {
      await expect(this.chef2.init(this.dummy.address)).to.be.revertedWith("Balance must exceed 0")
    })
  })

  describe("PoolLength", function () {
    it("PoolLength should execute", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      expect(await this.chef2.poolLength()).to.be.equal(1)
    })
  })

  describe("Set", function () {
    it("Should emit event LogSetPool", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await expect(this.chef2.set(0, 10, [this.rewarder.address], false))
        .to.emit(this.chef2, "LogSetPool")
        //.withArgs(0, 10, [this.rewarder.address], false)
      await expect(this.chef2.set(0, 10, [this.dummy.address], true)).to.emit(this.chef2, "LogSetPool")//.withArgs(0, 10, [this.dummy.address], true)
    })

    it("Should revert if invalid pool", async function () {
      await expect(this.chef2.set(0, 10, [this.rewarder.address], false)).to.be.reverted
    })
  })

  describe("PendingBoo", function () {
    it("PendingBoo should equal ExpectedBoo", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await this.rlp.approve(this.chef2.address, getBigNumber(10))
      let log = await this.chef2.deposit(0, getBigNumber(1), this.alice.address)
      await advanceBlock()
      let log2 = await this.chef2.updatePool(0)
      await advanceBlock()
      let expectedBoo = getBigNumber(100)
        .mul(log2.blockNumber + 1 - log.blockNumber)
        .div(2)
      let pendingBoo = await this.chef2.pendingBoo(0, this.alice.address)
      expect(pendingBoo).to.be.equal(expectedBoo)
    })
    it("When block is lastRewardBlock", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await this.rlp.approve(this.chef2.address, getBigNumber(10))
      let log = await this.chef2.deposit(0, getBigNumber(1), this.alice.address)
      await advanceBlockTo(3)
      let log2 = await this.chef2.updatePool(0)
      let expectedBoo = getBigNumber(100)
        .mul(log2.blockNumber - log.blockNumber)
        .div(2)
      let pendingBoo = await this.chef2.pendingBoo(0, this.alice.address)
      expect(pendingBoo).to.be.equal(expectedBoo)
    })
  })

  describe("MassUpdatePools", function () {
    it("Should call updatePool", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await advanceBlockTo(1)
      await this.chef2.massUpdatePools([0])
      //expect('updatePool').to.be.calledOnContract(); //not suported by heardhat
      //expect('updatePool').to.be.calledOnContractWith(0); //not suported by heardhat
    })

    it("Updating invalid pools should fail", async function () {
      await expect(this.chef2.massUpdatePools([0, 10000, 100000])).to.be.reverted
    })
  })

  describe("Add", function () {
    it("Should add pool with reward token multiplier", async function () {
      await expect(this.chef2.add(10, this.rlp.address, [this.rewarder.address]))
        .to.emit(this.chef2, "LogPoolAddition")
        //.withArgs(0, 10, this.rlp.address, [this.rewarder.address])
    })
  })

  describe("UpdatePool", function () {
    it("Should emit event LogUpdatePool", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await advanceBlockTo(1)
      await expect(this.chef2.updatePool(0))
        .to.emit(this.chef2, "LogUpdatePool")
        /*.withArgs(
          0,
          (await this.chef2.poolInfo(0)).lastRewardBlock,
          await this.rlp.balanceOf(this.chef2.address),
          (await this.chef2.poolInfo(0)).accBooPerShare
        )*/
    })

    /*it("Should take else path", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await advanceBlockTo(1)
      await this.chef2.batch(
        [this.chef2.interface.encodeFunctionData("updatePool", [0]), this.chef2.interface.encodeFunctionData("updatePool", [0])],
        true
      )
    })*/
  })

  describe("Deposit", function () {
    it("Depositing 0 amount", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await this.rlp.approve(this.chef2.address, getBigNumber(10))
      await expect(this.chef2.deposit(0, getBigNumber(0), this.alice.address))
        .to.emit(this.chef2, "Deposit")
        .withArgs(this.alice.address, 0, 0, this.alice.address)
    })

    it("Depositing into non-existent pool should fail", async function () {
        await expect(this.chef2.deposit(1001, getBigNumber(0), this.alice.address)).to.be.reverted
    })
  })

  describe("Withdraw", function () {
    it("Withdraw 0 amount", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await expect(this.chef2.withdraw(0, getBigNumber(0), this.alice.address))
        .to.emit(this.chef2, "Withdraw")
        .withArgs(this.alice.address, 0, 0, this.alice.address)
    })
  })

  describe("Harvest", function () {
    it("Should give back the correct amount of Boo and reward", async function () {
      await this.r.transfer(this.rewarder.address, getBigNumber(100000))
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await this.rlp.approve(this.chef2.address, getBigNumber(10))
      expect(await this.chef2.lpToken(0)).to.be.equal(this.rlp.address)
      let log = await this.chef2.deposit(0, getBigNumber(1), this.alice.address)
      await advanceBlockTo(20)
      await this.chef2.harvestFromMasterChef()
      let log2 = await this.chef2.withdraw(0, getBigNumber(1), this.alice.address)
      console.log("here")
      let expectedBoo = getBigNumber(100)
        .mul(log2.blockNumber - log.blockNumber)
        .div(2)
      expect((await this.chef2.userInfo(0, this.alice.address)).rewardDebt).to.be.equal("-" + expectedBoo)
      await this.chef2.harvest(0, this.alice.address)
      expect(await this.Boo.balanceOf(this.alice.address))
        .to.be.equal(await this.r.balanceOf(this.alice.address))
        .to.be.equal(expectedBoo)
    })
    it("Harvest with empty user balance", async function () {
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await this.chef2.harvest(0, this.alice.address)
    })

    it("Harvest for Boo-only pool", async function () {
      await this.chef2.add(10, this.rlp.address, [ADDRESS_ZERO])
      await this.rlp.approve(this.chef2.address, getBigNumber(10))
      expect(await this.chef2.lpToken(0)).to.be.equal(this.rlp.address)
      let log = await this.chef2.deposit(0, getBigNumber(1), this.alice.address)
      await advanceBlock()
      await this.chef2.harvestFromMasterChef()
      let log2 = await this.chef2.withdraw(0, getBigNumber(1), this.alice.address)
      let expectedBoo = getBigNumber(100)
        .mul(log2.blockNumber - log.blockNumber)
        .div(2)
      expect((await this.chef2.userInfo(0, this.alice.address)).rewardDebt).to.be.equal("-" + expectedBoo)
      await this.chef2.harvest(0, this.alice.address)
      expect(await this.Boo.balanceOf(this.alice.address)).to.be.equal(expectedBoo)
    })
  })

  describe("EmergencyWithdraw", function () {
    it("Should emit event EmergencyWithdraw", async function () {
      await this.r.transfer(this.rewarder.address, getBigNumber(100000))
      await this.chef2.add(10, this.rlp.address, [this.rewarder.address])
      await this.rlp.approve(this.chef2.address, getBigNumber(10))
      await this.chef2.deposit(0, getBigNumber(1), this.bob.address)
      //await this.chef2.emergencyWithdraw(0, this.alice.address)
      await expect(this.chef2.connect(this.bob).emergencyWithdraw(0, this.bob.address))
        .to.emit(this.chef2, "EmergencyWithdraw")
        .withArgs(this.bob.address, 0, getBigNumber(1), this.bob.address)
    })
  })
})