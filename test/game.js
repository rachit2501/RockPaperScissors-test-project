const { assert } = require("hardhat")

const ERC20 = artifacts.require("DAI")
const Contract = artifacts.require("RockPaperScissors")

describe("Contract RockPaperScissors", () => {
  let accounts
  let erc20
  let Game
  let gameHash

  before(async function () {
    accounts = await web3.eth.getAccounts()
    erc20 = await ERC20.new()
    Game = await Contract.new(erc20.address)
  })

  describe("ERC20 accounts funding", async () => {
    it("Account gets some dai for account 0: Alice and account1: Bob", async () => {
      await erc20.mint(accounts[0], 100000, { from: accounts[0] })
      const value1 = await erc20.balanceOf(accounts[0])
      assert.equal(value1, 100000)
      await erc20.mint(accounts[1], 100000, { from: accounts[1] })
      const value2 = await erc20.balanceOf(accounts[1])
      assert.equal(value2, 100000)
    })
  })

  describe("Game FLow", async () => {
    it("both Alice and Bob are able to enroll", async () => {
      await erc20.approve(Game.address, 2000, { from: accounts[0] })
      await erc20.approve(Game.address, 2000, { from: accounts[1] })
      await Game.enroll(2000, { from: accounts[0] })
      await Game.enroll(2000, { from: accounts[1] })
      assert.equal(await Game.getPlayerEnrollmentStatus(accounts[0]), true)
      assert.equal(await Game.getPlayerEnrollmentStatus(accounts[1]), true)
    })

    it("Alice sends match request to Bob", async () => {
      await Game.matchRequest(accounts[1], { from: accounts[0] })
      assert.equal(await Game.getMatch({ from: accounts[1] }), accounts[0])
    })

    it("Bob accepts Alice request", async () => {
      await Game.confirmMatch({ from: accounts[1] })
      gameHash = await Game.getGameHash(accounts[0], accounts[1])
      const game = await Game.getGameMapping(gameHash)
      assert.equal(game.player1, accounts[0])
      assert.equal(game.player2, accounts[1])
    })

    it("Alice makes her move: Rock", async () => {
      let game = await Game.getGameMapping(gameHash)
      assert.equal(game.move1, 3)
      await Game.submitMove(gameHash, 0, { from: accounts[0] })
      game = await Game.getGameMapping(gameHash)
      assert.equal(game.move1, 0)
    })

    it("Now Bob makes his move: Paper and wins ", async () => {
      const aliceInitial = await Game.getPlayerDetails(accounts[0])
      const bobInitial = await Game.getPlayerDetails(accounts[1])

      assert.equal(aliceInitial, 2000)
      assert.equal(bobInitial, 2000)

      await Game.submitMove(gameHash, 1, { from: accounts[1] })

      const aliceFinal = await Game.getPlayerDetails(accounts[0])
      const bobFinal = await Game.getPlayerDetails(accounts[1])

      assert.equal(aliceFinal, 0)
      assert.equal(bobFinal, 4000)
    })
  })
})
