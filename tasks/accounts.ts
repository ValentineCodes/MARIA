import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

task("accounts", "Prints the list of accounts").setAction(
  async (hre: HardhatRuntimeEnvironment): Promise<void> => {
    const accounts: SignerWithAddress[] = await hre.ethers.getSigners();

    for (const account of accounts) {
      console.log(account.address);
    }
  }
);
