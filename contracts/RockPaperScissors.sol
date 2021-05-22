//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract RockPaperScissors {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    enum Moves {rock, paper, scissor, none}
    struct Game {
        address player1;
        address player2;
        Moves move1;
        Moves move2;
        uint256 timestamp;
    }

    // events
    event Enroll(address player);
    event Move(address indexed player, Moves move);
    event MatchResult(address Winner, address Looser);

    // state variables
    IERC20 public ERC20Token;
    mapping(address => uint256) playerMapping;
    mapping(address => bool) enrollmentStatus;
    mapping(bytes32 => Game) GameMapping;
    mapping(address => address) createMatchRequest;

    constructor(IERC20 token) {
        ERC20Token = token;
    }

    /*
     * Function to register a user to play by depositing their bets
     * @param {uint256} amount - amount approved and then deposited to this smart contract
     */

    function enroll(uint256 amount) public {
        // needs to aproove first
        ERC20Token.safeTransferFrom(msg.sender, address(this), amount);
        enrollmentStatus[msg.sender] = true;
        playerMapping[msg.sender] += amount;
        emit Enroll(msg.sender);
    }

    /*
     * Function to submit their move. 0: Rock 1: Paper 2: Scissor 3: None (default state)
     * @param {bytes32} gameHash - hash of the game registered
     * @param {uint8} move - Move the user made
     */

    function submitMove(bytes32 gameHash, uint8 move) public {
        Game storage game = GameMapping[gameHash];
        require(
            game.player1 != address(0) && game.player2 != address(0),
            'Game not started yet'
        );
        require(
            enrollmentStatus[msg.sender] == true,
            'Not enrolled for any game'
        );
        require(
            game.player1 == msg.sender || game.player2 == msg.sender,
            'Wrong game id. User not registered to this particular matching'
        );
        require(move < uint8(Moves.none), 'invalid move');

        emit Move(msg.sender, Moves(move));

        // assigning move to player number i.e. move1 for player1 and move2 for player2

        if (game.player1 == msg.sender) {
            require(game.move1 == Moves.none, 'already played your move');
            game.move1 = Moves(move);
        } else {
            require(game.move2 == Moves.none, 'already played your move');
            game.move2 = Moves(move);
            gameEngine(game);
        }
    }

    /*
     * Function to handle Player one adds match request for Player2
     * @param {address} opponent : address of the opponent to match agains
     */

    function matchRequest(address opponent) public {
        require(
            enrollmentStatus[msg.sender] == true &&
                enrollmentStatus[opponent] == true,
            'Already Enrolled'
        );
        require(createMatchRequest[opponent] == address(0), 'Already Matched');

        createMatchRequest[opponent] = msg.sender;
        createMatchRequest[msg.sender] = opponent;
    }

    function getMatch() public view returns (address) {
        return createMatchRequest[msg.sender];
    }

    /*
     * The following functions: confirmMatch and rejectMatch is called if a match request was made
     */
    function confirmMatch() public {
        address opponent = createMatchRequest[msg.sender];
        require(opponent != address(0), 'No request found');
        GameMapping[getGameHash(opponent, msg.sender)] = Game({
            player1: opponent,
            player2: msg.sender,
            move1: Moves.none,
            move2: Moves.none,
            timestamp: block.timestamp
        });
    }

    function rejectMatch() public {
        address opponent = createMatchRequest[msg.sender];
        createMatchRequest[opponent] = address(0);
        createMatchRequest[msg.sender] = address(0);
    }

    /*
     * Function to generate a gamehash for faster and cheaper queries using participants public address
     * @param player1 - address of player1
     * @param player2 - address of player2
     */

    function getGameHash(address player1, address player2)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(player1, player2));
    }

    /*
     * Internal function to get executed whenever both the moves are availaible in the game
     * @param game - a game instance of storage type ( for persistant changes )
     */

    function gameEngine(Game storage game) internal {
        Moves move1 = game.move1;
        Moves move2 = game.move2;

        if (move1 == Moves.rock && move2 == Moves.rock) {
            resetGame(game);
        } else if (move1 == Moves.rock && move2 == Moves.paper) {
            reward(game.player2, game.player1);
        } else if (move1 == Moves.rock && move2 == Moves.scissor) {
            reward(game.player1, game.player2);
        } else if (move1 == Moves.paper && move2 == Moves.rock) {
            reward(game.player1, game.player2);
        } else if (move1 == Moves.paper && move2 == Moves.paper) {
            resetGame(game);
        } else if (move1 == Moves.paper && move2 == Moves.scissor) {
            reward(game.player2, game.player1);
        } else if (move1 == Moves.scissor && move2 == Moves.rock) {
            reward(game.player2, game.player1);
        } else if (move1 == Moves.scissor && move2 == Moves.scissor) {
            resetGame(game);
        } else {
            reward(game.player1, game.player2);
        }
    }

    function resetGame(Game storage game) internal {
        game.move1 = Moves.none;
        game.move2 = Moves.none;
    }

    function reward(address winner, address looser) internal {
        uint256 valueLost = playerMapping[looser];
        playerMapping[winner] += valueLost; // since the value lost is kept in track, the player can use their winnings in future matches by just enrolling with 0 amount
        playerMapping[looser] -= valueLost;
        createMatchRequest[winner] = address(0);
        createMatchRequest[looser] = address(0);
        enrollmentStatus[winner] = false;
        enrollmentStatus[looser] = false;
        emit MatchResult(winner, looser);
    }

    function withdraw() public {
        require(enrollmentStatus[msg.sender] == false, 'In match');
        ERC20Token.safeTransfer(msg.sender, playerMapping[msg.sender]);
        playerMapping[msg.sender] = 0;
    }

    /*
     * Function to entice players to play. If the other side doesn't make their move within 1hr, the calling player can get all the funds
     * @param gameHash - gameHash of the game player is up against
     * @param opponent - opponent address to liquidate
     */

    function entice(bytes32 gameHash, address opponent) public {
        Game memory game = GameMapping[gameHash];
        require(
            block.timestamp - game.timestamp > 1 hours,
            'Wait a bit more. Liquidation time is 1 hr'
        );
        require(
            ((game.player1 == msg.sender && game.player2 == opponent) &&
                game.move2 == Moves.none) ||
                (game.player2 == msg.sender &&
                    game.player1 == opponent &&
                    game.move1 == Moves.none),
            'Wrong Opponent Address'
        );

        uint256 liquidity = playerMapping[opponent];
        playerMapping[opponent] -= liquidity;
        playerMapping[msg.sender] += liquidity;
    }

    // Helper functions

    function getPlayerEnrollmentStatus(address player)
        public
        view
        returns (bool)
    {
        return enrollmentStatus[player];
    }

    function getGameMapping(bytes32 gameHash)
        public
        view
        returns (Game memory)
    {
        return GameMapping[gameHash];
    }

    function getPlayerDetails(address player) public view returns (uint256) {
        return playerMapping[player];
    }
}
