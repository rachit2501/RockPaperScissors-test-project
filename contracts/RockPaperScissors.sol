//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

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

    IERC20 public ERC20Token;
    mapping(address => uint256) playerMapping;
    mapping(address => bool) enrollmentStatus;
    mapping(bytes32 => Game) GameMapping;
    mapping(address => address) createMatchRequest;

    constructor(IERC20 token) {
        ERC20Token = token;
    }

    function enroll(uint256 amount) {
        ERC20Token.safeApprove(msg.sender, amount);
        ERC20Token.safeTransferFrom(msg.sender, address(this), amount);
        enrollmentStatus[msg.sender] = true;
        playerMapping[msg.sender] += amount;
    }

    function submitMove(bytes32[] gameHash, uint8 move) public {
        Game game = GameMapping[gameHash];
        require(
            game.player1 != '' && game.player2 != '',
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
        require(newDir <= uint8(Moves.scissor), 'invalid move');
        require(game.move1 == Moves.none || game.move2 == Moves.none);

        if (game.player1 == msg.sender) game.move1 = Moves(move);
        else {
            game.move2 = Moves(move);
            gameEngine(game);
        }
    }

    function matchRequest(address opponent) public {
        require(
            enrollmentStatus[msg.sender] == false &&
                enrollmentStatus[opponent] == false,
            'Already Enrolled'
        );
        require(createMatchRequest[opponent] != address(0));

        createMatchRequest[opponent] = msg.sender;
    }

    function getMatch() public view {
        return createMatchRequest[msg.sender];
    }

    function confirmMatch(address player) public {
        address opponent = createMatchRequest[msg.sender];
        require(opponent != address(0), 'No request found');
        GameMapping[getGameHash(msg.sender, player)] = Game({
            player1: player,
            player2: msg.sender,
            move1: Moves.none,
            move2: Moves.none,
            timestamp: now
        });
    }

    function getGameHash(address player1, address player2)
        public
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(player1, player2));
    }

    function gameEngine(Game game) public {
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
            reward(player2, player1);
        } else if (move1 == Moves.scissor && move2 == Moves.scissor) {
            resetGame(game);
        } else {
            reward(player1, player2);
        }
    }

    function resetGame(Game game) internal {
        game.move1 = Moves.none;
        game.move2 = Moves.none;
    }

    function reward(address winner, address looser) internal {
        uint256 valueLost = playerMapping[looser];
        playerMapping[winner] += valueLost;
        playerMapping[looser] -= valueLost;
    }

    function withdraw() public {
        ERC20Token.safeTransfer(msg.sender, playerMapping[msg.sender]);
        playerMapping[msg.sender] = 0;
    }

    function entice(bytes32 gameHash, address opponent) public {
        Game game = GameMapping[GameMapping];
        require(
            now - game.timestamp > 1 hours,
            'Wait a bit more. Liquidation time is 1 hr'
        );
        require(
            (game.player1 == msg.sender && game.player2 == opponent) ||
                (game.player2 == msg.sender && game.player1 == opponent),
            'Wrong Opponent Address'
        );
        uint256 liquidity = playerMapping[opponent];
        playerMapping[opponent] -= liquidity;
        playerMapping[msg.sender] += liquidity;
    }
}
