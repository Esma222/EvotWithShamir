// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract BallotWithShamirSecret {
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

    mapping(address => Voter) public voters;
    Candidate[] public candidates;

    enum State { Created, Voting, Ended }
    State public state;

    event VoteReceived(address indexed voter, uint indexed candidate, uint secretShare);

    uint256[] public coefficients; // Polynomial coefficients

    constructor(string[] memory candidateNames, uint _totalVoters, uint _threshold, address[] memory voterAddresses) {
        chairperson = msg.sender;
        totalVoters = _totalVoters;
        threshold = _threshold;
        state = State.Created;

        // Initialize the candidates
        for (uint i = 0; i < candidateNames.length; i++) {
            candidates.push(Candidate({ name: candidateNames[i], voteCount: 0 }));
        }

        // Initialize voters and distribute secret shares
        for (uint i = 0; i < voterAddresses.length; i++) {
            voters[voterAddresses[i]].weight = 1; // Give voting power to each voter
        }

        // Generate the polynomial coefficients and distribute secret shares
        generateSecretShares(voterAddresses);
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
    function generateSecretShares(address[] memory voterAddresses) private {
        // Define a secret number (sırrı sabit bir sayı yerine burada oluşturuyoruz)
        uint secret = uint(keccak256(abi.encodePacked(block.timestamp)));

        // Generate random polynomial coefficients
        coefficients.push(secret); // secret is the constant term of the polynomial
        for (uint i = 1; i < threshold; i++) {
            coefficients.push(uint(keccak256(abi.encodePacked(block.timestamp, i))) % 100); // Random coefficients
        }

        // Distribute secret shares to voters based on polynomial evaluation
        uint share;
        for (uint i = 0; i < voterAddresses.length; i++) {
            share = evaluatePolynomial(i + 1);  // Using i+1 as the x value for polynomial evaluation
            voters[voterAddresses[i]].secretShare = share;
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
        for (uint i = 0; i < totalVoters; i++) {
            totalShares += voters[address(uint160(i))].secretShare; // Add up all shares
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
    
    // Get voter’s secret share (for testing purposes)
    function getVoterSecretShare(address voterAddress) public view returns (uint) {
        return voters[voterAddress].secretShare;
    }
}
