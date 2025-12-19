import hre from "hardhat";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";

await verifyContract(
  {
    address: "DEPLOYED_CONTRACT_ADDRESS",
    constructorArgs: ["Constructor argument 1"],
    provider: "etherscan", // or "blockscout", or "sourcify"
  },
  hre,
);
