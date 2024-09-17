const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LudoModule", (m) => {
  const tokenAdress = "";

  const ludo = m.contract("Ludo", [tokenAdress], {});

  return { ludo };
});
