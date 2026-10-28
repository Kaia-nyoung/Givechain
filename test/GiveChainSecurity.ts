
import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("GiveChain Security", function () {
  let giveChain: any;
  let owner: any;
  let beneficiary: any;
  let donorA: any;
  let donorB: any;

  beforeEach(async function () {
    [owner, beneficiary, donorA, donorB] =
      await ethers.getSigners();

    const factory =
      await ethers.getContractFactory("GiveChain");

    giveChain = await factory.deploy();
    await giveChain.waitForDeployment();

    await giveChain.createCampaign(
      "Security Test",
      ethers.parseEther("5"),
      beneficiary.address
    );
  });

  // 1. 접근 제어
  it("blocks unauthorized withdrawal", async function () {
    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("5")
    });

    await giveChain.finalizeCampaign(0);

    await expect(
      giveChain.connect(donorA).withdraw(0)
    ).to.be.revertedWith("Only beneficiary");
  });

  // 2. 상태 전이
  it("blocks donation after finalization", async function () {
    await giveChain.finalizeCampaign(0);

    await expect(
      giveChain.connect(donorA).donate(0, {
        value: ethers.parseEther("1")
      })
    ).to.be.revertedWith("Campaign is not open");
  });

  // 3. 중복 환불
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

  // 4. 재진입 공격 검증
  it("prevents reentrancy attack", async function () {
    const attackerFactory =
      await ethers.getContractFactory("RefundAttacker");

    const attacker = await attackerFactory.deploy(
      await giveChain.getAddress()
    );

    await attacker.waitForDeployment();

    // 공격자 컨트랙트가 1 ETH 기부
    await attacker.donateToCampaign(0, {
      value: ethers.parseEther("1")
    });

    // 일반 기부자가 2 ETH 기부
    await giveChain.connect(donorB).donate(0, {
      value: ethers.parseEther("2")
    });

    // 목표 5 ETH 미달이므로 FAILED
    await giveChain.finalizeCampaign(0);

    const contractAddress =
      await giveChain.getAddress();

    const balanceBefore =
      await ethers.provider.getBalance(contractAddress);

    expect(balanceBefore).to.equal(
      ethers.parseEther("3")
    );

    // 재진입 공격 시도
    await attacker.attack(0);

    const balanceAfter =
      await ethers.provider.getBalance(contractAddress);

    // 재진입 시도는 실패해야 함
    expect(await attacker.reentryAttempts()).to.equal(1n);
    expect(await attacker.reentryBlocked()).to.equal(true);

    // 공격자는 정상 환불액인 1 ETH만 수령
    expect(await attacker.totalReceived()).to.equal(
      ethers.parseEther("1")
    );

    // 기부 장부는 0으로 초기화
    expect(
      await giveChain.donations(
        0,
        await attacker.getAddress()
      )
    ).to.equal(0n);

    // 컨트랙트에는 2 ETH가 남아야 함
    expect(balanceAfter).to.equal(
      ethers.parseEther("2")
    );
  });

  // 5. 실제 잔액과 내부 장부 일치
  it("maintains accounting consistency", async function () {
    await giveChain.connect(donorA).donate(0, {
      value: ethers.parseEther("1")
    });

    await giveChain.connect(donorB).donate(0, {
      value: ethers.parseEther("2")
    });

    const campaign = await giveChain.campaigns(0);

    const balance = await ethers.provider.getBalance(
      await giveChain.getAddress()
    );

    expect(campaign.raised).to.equal(balance);
    expect(balance).to.equal(ethers.parseEther("3"));

    // FAILED 이후 환불
    await giveChain.finalizeCampaign(0);
    await giveChain.connect(donorA).refund(0);

    const updatedCampaign = await giveChain.campaigns(0);

    const updatedBalance =
      await ethers.provider.getBalance(
        await giveChain.getAddress()
      );

    expect(updatedCampaign.raised).to.equal(
      updatedBalance
    );

    expect(updatedBalance).to.equal(
      ethers.parseEther("2")
    );
  });
});
