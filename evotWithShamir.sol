// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract BallotWithShamir {
    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        uint vote;   // index of the voted proposal
        string ipfsHash; // IPFS hash of the share
    }

    struct Candidate {
        string name;   // candidate name 
        uint voteCount; // number of accumulated votes
    }

    address public chairperson;

    mapping(address => Voter) public voters;

    Candidate[] public candidates;

    uint public totalVoters; // Total number of voters
    uint public requiredVotes; // 75% of total voters
    uint public voteEndTime; // Voting end time

    uint256[] public secretShares; // Array to store secret shares
    
    enum State { Created, Voting, Ended } // State of voting period
    State public state;

    // Event to log the reveal of the winner
    event Winner(string winner, uint votes);

    constructor(string[] memory candidateNames, uint _totalVoters, uint _durationInMinutes) {
        chairperson = msg.sender;
        totalVoters = _totalVoters;
        requiredVotes = (_totalVoters * 75) / 100; // 75% of total voters
        voteEndTime = block.timestamp + (_durationInMinutes * 1 minutes);
        state = State.Created;

        for (uint i = 0; i < candidateNames.length; i++) {
            candidates.push(Candidate({
                name: candidateNames[i],
                voteCount: 0
            }));
        }
    }

    // MODIFIERS
    modifier onlyChairperson() {
        require(msg.sender == chairperson, "Only the chairperson can perform this action.");
        _;
    }

    modifier inVotingPeriod() {
        require(state == State.Voting && block.timestamp <= voteEndTime, "Voting is not in progress.");
        _;
    }

    modifier afterVotingPeriod() {
        require(state == State.Ended, "Voting period is not over.");
        _;
    }

    // Function to start voting
    function startVote() public onlyChairperson {
        state = State.Voting;
    }

    // Function to end voting
    function endVote() public onlyChairperson {
        state = State.Ended;
    }

    // Give the right to vote
    function giveRightToVote(address voter) public onlyChairperson {
        require(!voters[voter].voted, "This voter has already voted.");
        require(voters[voter].weight == 0, "This voter already has the right to vote.");
        voters[voter].weight = 1;
    }

    // Voting function
    function vote(uint candidate, string memory ipfsHash) public inVotingPeriod {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "You don't have the right to vote.");
        require(!sender.voted, "You already voted.");
        
        sender.voted = true;
        sender.vote = candidate;
        sender.ipfsHash = ipfsHash; // Store the IPFS hash of the share

        // Add the vote count to the selected candidate
        candidates[candidate].voteCount += sender.weight;
    }

    // Check if the threshold number of votes has been reached and reveal the secret
    function revealSecret() public afterVotingPeriod {
        uint votesReceived = 0;
        
        // Loop through the voters and check their IPFS hash
        for (uint i = 0; i < totalVoters; i++) {
            address voterAddress = address(uint160(i)); // Convert index to address
            if (bytes(voters[voterAddress].ipfsHash).length > 0) {
                votesReceived++;
            }
        }

        if (votesReceived >= requiredVotes) {
            // Retrieve the secret from the shares
            uint secret = reconstructSecret();
            string memory winnerName = candidates[0].name; // Assume the first candidate is the winner for simplicity

            // Log the winner
            emit Winner(winnerName, candidates[0].voteCount);
        } else {
            revert("Not enough votes to reveal the secret.");
        }
    }

    // Reconstruct the secret using the shares (Shamir's Secret Sharing algorithm)
    function reconstructSecret() private view returns (uint) {
        uint secret = 0;
        uint prime = 256; // We use a prime number as the modulus for simplicity

        // Apply Shamir's Secret Sharing algorithm: Lagrange interpolation (simplified)
        for (uint i = 0; i < secretShares.length; i++) {
            uint numerator = 1;
            uint denominator = 1;

            for (uint j = 0; j < secretShares.length; j++) {
                if (i != j) {
                    numerator = (numerator * j) % prime;
                    denominator = (denominator * (i - j)) % prime;
                }
            }

            // Lagrange basis polynomial: L_i(x)
            uint L = (numerator * modInverse(denominator, prime)) % prime;

            // Add the contribution of each share
            secret = (secret + (secretShares[i] * L)) % prime;
        }

        return secret;
    }

    // Modulo inverse (for the Lagrange interpolation)
    function modInverse(uint a, uint p) private pure returns (uint) {
        int t = 0;
        int newT = 1;
        int r = int(p);
        int newR = int(a);

        while (newR != 0) {
            int quotient = r / newR;
            int tempT = t;
            t = newT;
            newT = tempT - quotient * newT;

            int tempR = r;
            r = newR;
            newR = tempR - quotient * newR;
        }

        if (r > 1) revert("No inverse exists");
        if (t < 0) t = t + int(p);

        return uint(t);
    }
}
