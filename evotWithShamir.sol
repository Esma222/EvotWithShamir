// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract BallotWithShamir {
    struct Voter {
        uint weight;
        bool voted;
        uint vote;
        uint secretShare;
    }

    struct Candidate {
        string name;
        uint voteCount;
    }

    address public chairperson;
    uint public threshold;
    uint public totalVoters;
    uint public currentVoters;
    uint public secret;

    mapping(address => Voter) public voters;
    Candidate[] public candidates;

    enum State { Created, Voting, Ended }
    State public state;

    event VoteReceived(address indexed voter, uint indexed candidate, uint secretShare);

    // Shamir Secret Sharing coefficients and polynomial degree
    uint256[] public coefficients;

    constructor(string[] memory candidateNames, uint _totalVoters, uint _secret, uint _threshold) {
        chairperson = msg.sender;
        totalVoters = _totalVoters;
        secret = _secret;
        threshold = _threshold; // Set threshold equal to the number of voters
        state = State.Created;

        // Initialize the candidates
        for (uint i = 0; i < candidateNames.length; i++) {
            candidates.push(Candidate({ name: candidateNames[i], voteCount: 0 }));
        }

        // Generate the polynomial coefficients and distribute secret shares
        generateSecretShares();
    }

    modifier onlyChairperson() {
        require(msg.sender == chairperson, "Only chairperson can perform this action.");
        _;
    }

    modifier inVotingPeriod() {
        require(state == State.Voting, "Voting is not in progress.");
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

    // Function to give right to vote
    function giveRightToVote(address voter) public onlyChairperson {
        require(!voters[voter].voted, "This voter has already voted.");
        require(voters[voter].weight == 0, "This voter already has the right to vote.");
        voters[voter].weight = 1;
    }

    // Shamir's Secret Sharing: Generate secret shares for all participants
    function generateSecretShares() private {
        // Generate random polynomial coefficients, for simplicity using fixed coefficients here
        coefficients.push(secret); // secret is the constant term of the polynomial
        for (uint i = 1; i < threshold; i++) {
            coefficients.push(uint(keccak256(abi.encodePacked(block.timestamp, i))) % 100); // Random coefficients
        }

        // Distribute secret shares (using a simplified polynomial evaluation)
        for (uint i = 1; i <= totalVoters; i++) {
            uint share = evaluatePolynomial(i);
            voters[chairperson].secretShare = share; // Assign the share to each voter
        }
    }

    // Polynomial evaluation function: f(x) = a0 + a1*x + a2*x^2 + ...
    function evaluatePolynomial(uint x) private view returns (uint) {
        uint result = 0;
        for (uint i = 0; i < coefficients.length; i++) {
            result += coefficients[i] * (x**i);
        }
        return result;
    }

    // Voting function
    function vote(uint candidateIndex, uint secretShare) public inVotingPeriod {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "You don't have the right to vote.");
        require(!sender.voted, "You have already voted.");
        require(secretShare == sender.secretShare, "Invalid secret share.");

        sender.voted = true;
        sender.vote = candidateIndex;
        candidates[candidateIndex].voteCount += sender.weight;

        emit VoteReceived(msg.sender, candidateIndex, secretShare);
    }

    // Function to reveal the secret and calculate the result
    function revealResult() public afterVotingPeriod {
        uint reconstructedSecret = reconstructSecret();
        string memory winnerName = getWinner();

        emit Winner(winnerName, reconstructedSecret);
    }

    // Reconstruct the secret using the shares
    function reconstructSecret() private view returns (uint) {
        uint totalShares = 0;
        for (uint i = 1; i <= totalVoters; i++) {
            totalShares += voters[chairperson].secretShare; // Add up all shares
        }
        return totalShares / totalVoters; // Simplified calculation for demo purposes
    }

    // Function to get the winning candidate
    function getWinner() private view returns (string memory) {
        uint winningVoteCount = 0;
        string memory winnerName;
        for (uint p = 0; p < candidates.length; p++) {
            if (candidates[p].voteCount > winningVoteCount) {
                winningVoteCount = candidates[p].voteCount;
                winnerName = candidates[p].name;
            }
        }
        return winnerName;
    }

    event Winner(string winner, uint reconstructedSecret);
}
