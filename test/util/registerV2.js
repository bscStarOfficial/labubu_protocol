const {ethers} = require("hardhat");

async function setReferrer(referral, referrer = "") {
  let registerV2 = await ethers.getContract("RegisterV2");

  if (referrer === "") referrer = await registerV2.ROOT_USER();
  await registerV2.setReferral(referral.address, referrer.address);
}

async function referrer(account) {
  let registerV2 = await ethers.getContract("RegisterV2");
  return await registerV2.referrers(account.address)
}


module.exports = {
  setReferrer,
  referrer
}
