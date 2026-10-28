import { defineConfig } from "hardhat/config";
import toolbox from "@nomicfoundation/hardhat-toolbox-mocha-ethers";

export default defineConfig({
  plugins: [toolbox],
  solidity: "0.8.20",
});