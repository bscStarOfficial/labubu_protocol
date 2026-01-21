const {time} = require("@nomicfoundation/hardhat-network-helpers")

async function utcZeroTime() {
  let now = await time.latest();
  let days = parseInt((now - 1766188800) / 86400);
  return days * 86400 + 1766188800;
}

module.exports.utcZeroTime = utcZeroTime;
