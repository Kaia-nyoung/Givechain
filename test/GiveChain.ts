
import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("GiveChain", function () {
  let giveChain: any;
  let admin: any;
  let beneficiary: any;
  let donorA: any;
  let donorB: any;

  beforeEach(async function () {
    [admin, beneficiary, donorA, donorB] =
      await ethers.getSigners();

    const factory = await ethers.getContractFactory("GiveChain");
    giveChain = await factory.deploy();
    await giveChain.waitForDeployment();

    await giveChain.createCampaign(
      "교육 지원",
      ethers.parseEther("5"),
      beneficiary.address
    );
  });

  it("creates campaign", async function () {
    const c = await giveChain.campaigns(0);

    expect(c.owner).to.equal(admin.address);
    expect(c.title).to.equal("교육 지원");
    expect(c.goal).to.equal(ethers.parseEther("5"));
    expect(c.raised).to.equal(0n);
    expect(c.beneficiary).to.equal(beneficiary.address);
    expect(c.stage).to.equal(1n);
  });

  it("accepts donation", async function () {
    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("1")
    });

    const c = await giveChain.campaigns(0);

    expect(c.raised).to.equal(ethers.parseEther("1"));
  });

  it("accumulates donations", async function () {
    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("1")
    });

    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("0.5")
    });

    expect(
      await giveChain.donations(0, donorA.address)
    ).to.equal(ethers.parseEther("1.5"));

    expect(
      await ethers.provider.getBalance(
        await giveChain.getAddress()
      )
    ).to.equal(ethers.parseEther("1.5"));
  });

  it("campaigns independent", async function () {
    await giveChain.createCampaign(
      "의료 지원",
      ethers.parseEther("3"),
      beneficiary.address
    );

    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("1")
    });

    const c0 = await giveChain.campaigns(0);
    const c1 = await giveChain.campaigns(1);

    expect(c0.raised).to.equal(ethers.parseEther("1"));
    expect(c1.raised).to.equal(0n);
  });

  it("refunds failed campaign", async function () {
    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("1")
    });

    await giveChain.finalizeCampaign(0);

    const c = await giveChain.campaigns(0);
    expect(c.stage).to.equal(3n);

    await giveChain.connect(donorA).refund(0);

    expect(
      await giveChain.donations(0, donorA.address)
    ).to.equal(0n);
  });

  it("prevents double refund", async function () {
    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("1")
    });

    await giveChain.finalizeCampaign(0);
    await giveChain.connect(donorA).refund(0);

    await expect(
      giveChain.connect(donorA).refund(0)
    ).to.be.revertedWith("No donation to refund");
  });

  it("rejects unauthorized withdraw", async function () {
    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("5")
    });

    await giveChain.finalizeCampaign(0);

    await expect(
      giveChain.connect(donorA).withdraw(0)
    ).to.be.revertedWith("Only beneficiary");
  });

  it("emits Donated event", async function () {
    await expect(
      giveChain.connect(donorA).donate(0, {
        value: ethers.parseEther("1")
      })
    )
      .to.emit(giveChain, "Donated")
      .withArgs(
        0n,
        donorA.address,
        ethers.parseEther("1")
      );
  });
});
