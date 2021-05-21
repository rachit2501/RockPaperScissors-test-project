const { Contract } = require("@ethersproject/contracts")
const { default: Web3 } = require("web3")

const Contract = artifacts.require("RockPaperScissors")

describe("Contract RockPaperScissors", () => {
  let accounts

  before(async function () {
    accounts = await web3.eth.getAccounts()
    contractInstance = await Contract.new()
  })
})
