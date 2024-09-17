// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Importing the ERC20 interface for token handling from Open Zepelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Ludo {
    struct Player {
        uint position;
        bool finished;
        bool inPlay; // Whether the player's token is on the board or still at "home"
    }

    IERC20 public entryToken;
    uint public entryFee = 100 * 10 ** 18;

    mapping(address => Player) public players;
    address[] public playerList;
    uint public totalPositions = 52;
    uint public maxPlayers = 4;
    uint public currentTurn = 0;

    event DiceThrown(address player, uint diceValue, uint newPosition);
    event PlayerCaptured(address capturer, address captured);

    modifier onlyPlayers() {
        require(
            players[msg.sender].inPlay == true ||
                players[msg.sender].finished == false,
            "You are not part of the game."
        );
        _;
    }

    modifier isPlayerTurn() {
        require(playerList[currentTurn] == msg.sender, "It's not your turn.");
        _;
    }

     constructor(IERC20 _tokenAddress) {
        entryToken = _tokenAddress;
    }

    // Function for players to pay and join the board
    function joinGame() public {
        // Make sure the game isn't full and the player hasn't already joined
        require(playerList.length < maxPlayers, "Game is full");
        require(
            players[msg.sender].inPlay == false &&
                players[msg.sender].finished == false,
            "You're already in the game"
        );

        // Make sure the player has enough tokens to pay the entry fee
        require(
            entryToken.balanceOf(msg.sender) >= entryFee,
            "Not enough tokens to join the game"
        );

        // Transfer the entry fee from the player to the contract
        require(
            entryToken.transferFrom(msg.sender, address(this), entryFee),
            "Token transfer failed"
        );

        // add player to the mapping
        players[msg.sender] = Player(0, false, false);
        playerList.push(msg.sender);
    }

    // Dice throwing logic with basic Ludo rules
    function throwDice() public onlyPlayers isPlayerTurn {
        require(
            players[msg.sender].finished == false,
            "You have already finished the game"
        );

        // Generate pseudorandom dice roll (between 1 and 6)

        uint diceValue = (uint(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
            )
        ) % 6) + 1;

        // check If the player has been inside,
        // meaning that they have not rolled a dice since another user captuired them
        // or they have not rolled 6 since the beginning of the gamee
        if (players[msg.sender].inPlay == false) {
            // like we used to play in norma ludo games,
            // if the user gets 6 they have the option  to bring out a token from
            // their square, or to continur playing with a token already on the board
            // since this contracr assumes that there is only one token, we will just bring it out

            if (diceValue == 6) {
                players[msg.sender].inPlay = true;

                // put them in position one, which in normal ludo game is "front of their house"

                players[msg.sender].position = 1;
            }
        } else {
            // if the player has already been in the game.
            // move the player forward by the number that their dice returned
            uint newPosition = players[msg.sender].position + diceValue;

            // If player exceeds total positions, they win
            // this means that they must have moved back into the square in the center of the ludo board

            if (newPosition >= totalPositions) {
                newPosition = totalPositions;
                players[msg.sender].finished = true;
            }

            // Update player's position
            players[msg.sender].position = newPosition;

            // Check if the players new position captures any other player's token
            checkCapture(msg.sender, newPosition);
        }

        emit DiceThrown(msg.sender, diceValue, players[msg.sender].position);

        // Move to the next player
        currentTurn = (currentTurn + 1) % playerList.length;
    }

    // Function to check if a player has captured another player's token
    // for example if you get 6 on your role, and you count ontop of another users token
    function checkCapture(address _currentPlayer, uint newPosition) internal {
        // we loop throuh all the players

        for (uint i = 0; i < playerList.length; i++) {
            address otherPlayer = playerList[i];

            // checking if there is another player in the same position and has not fincished playing
            // we first check of the current position is not the same person that we are checking for

            if (
                otherPlayer != _currentPlayer &&
                players[otherPlayer].position == newPosition &&
                players[otherPlayer].finished == false
            ) {
                // as it is on normal ludo games, when another user "eats" another persons token,
                // that token returns back to the house "inside the colored square"

                players[otherPlayer].position = 0;
                players[otherPlayer].inPlay = false;
                emit PlayerCaptured(_currentPlayer, otherPlayer);
            }
        }
    }
}
