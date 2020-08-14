const Tendermint_ORU = artifacts.require("Tendermint_ORU");

contract("Tendermint_ORU", async (accounts) => {
  it("should deploy", async () => {
    let instance = await Tendermint_ORU.deployed();
  });
});
