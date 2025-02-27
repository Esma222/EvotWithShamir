// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ShamirVoting {
    uint256 private secret; 
    uint256[] private coefficients; 

    struct Share {
        uint256 x;
        uint256 y;
    }

    struct Voter {
        bool hasVoted;
        Share share;
        address addr;
    }

    struct VoterHash {
        bool hasVoted;
        bytes32 hash; // y değerinin hash'ini tutacak alan
        address addr;
    }

    struct Candidate {
        string name;
        uint256 voteCount;
    }

    Candidate[] public candidates;
    Share[] public shares;
    mapping(address => Voter) public voters;
    mapping(address => VoterHash) private  votersHash;
    uint256 private requiredVotes;
    uint256 public totalVotes;
    uint256 private threshold;
    bool public votingStarted;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    modifier onlyVoter() {
    require(voters[msg.sender].addr != address(0), "Not authorized to vote");
    _;
    }
    function getVoterHash() public view returns (VoterHash memory) {
        return votersHash[msg.sender]; 
    }

    constructor(
        uint256 _threshold, 
        string[] memory candidateNames, 
        address[] memory voterAddresses
    ) {
        require(_threshold > 1, "Threshold must be greater than 1");
        require(candidateNames.length > 0, "At least one candidate required");
        require(voterAddresses.length > 1, "At least two voter required");
        require(_threshold <= voterAddresses.length, "Threshold must be smaller or equal to number of voter");

        threshold = _threshold;
        votingStarted = false;
        owner = msg.sender;

        for (uint256 i = 0; i < candidateNames.length; i++) {
            candidates.push(Candidate({name: candidateNames[i], voteCount: 0}));
        }
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            voters[voterAddresses[i]] = Voter(false, Share(0, 0), voterAddresses[i]);
            votersHash[voterAddresses[i]] = VoterHash(false,0, voterAddresses[i]);
        }

        requiredVotes = voterAddresses.length;
        generateSecretAndShares(voterAddresses);
    }

    function random() public view returns (uint256) {
        return uint(keccak256(abi.encodePacked(block.timestamp))) % 10000000000 ;// mod alınmadığı durum "execution reverted: arithmetic underflow or overflow"
    }
   
  
    function generateSecretAndShares(address[] memory voterAddresses) private {
        secret = random();

        coefficients.push(secret);  
        for (uint256 i = 1; i < threshold; i++) {
            coefficients.push(random()); 
        }

        for (uint256 i = 0; i < voterAddresses.length; i++) {
            uint256 x = i + 1;
            uint256 y = evaluatePolynomial(x);
            bytes32 yHash = keccak256(abi.encodePacked(y));
            voters[voterAddresses[i]].share = Share(x, y);
            votersHash[voterAddresses[i]].hash = yHash;
        }
    }


    // Sırrı paylaştırma işlemi
    function evaluatePolynomial(uint256 x) public view returns (uint256) {
        uint256 result = coefficients[0];
        uint256 power = 1;

        // P(x) = a0 + a1*x + a2*x^2 + ... 
        for (uint256 i = 1; i < coefficients.length; i++) {
            power *= x; 
            result += coefficients[i] * power;
        }
        return result;
    }

    // Oylamayı başlatır
    function startVoting() public onlyOwner {
        require(!votingStarted, "Voting already started");
        votingStarted = true;
    }

    // Oy kullanma yeni
    function vote(uint256 _x, uint256 _y) public onlyVoter {
        require(votingStarted, "Voting not started");
        require(!voters[msg.sender].hasVoted, "Already voted");

        bool correctVoting = false;
        uint256 candidateIndex = 0;
        //require(voters[msg.sender].share.x != _x ,"Invalid share");
        for(uint256 i = 0; i < candidates.length; i++)
        {
		if(_y - i == voters[msg.sender].share.y)
		{
			candidateIndex = i;
			_y = _y - i;
			correctVoting = true;
			break;	
		}
	}
        require(correctVoting, "Invalid share");

	Voter storage voter = voters[msg.sender];
        require(voter.share.x == _x && voter.share.y == _y, "Invalid share");
        shares.push(Share({x: _x, y: _y}));
        voters[msg.sender].hasVoted = true;
        votersHash[msg.sender].hasVoted = true;
        candidates[candidateIndex].voteCount += 1;
        totalVotes += 1;
    }

     // Lagrange İnterpolasyonu uygular
    function reconstructSecret() public view returns (uint256) {
        require(shares.length > 0, "Shares list is empty");
        int256 result = 0;

        for (uint256 i = 0; i < shares.length; i++) {
            int256 numerator = 1;
            int256 denominator = 1;

            for (uint256 j = 0; j < shares.length; j++) {
                if (i != j) {
                    require(shares[i].x != shares[j].x, "Error: x values must be unique!");
                    numerator = numerator * (0 - int256(shares[j].x));
                    denominator = denominator * (int256(shares[i].x) - int256(shares[j].x));
                }
            }
            require(denominator != 0, "Error: Denominator is zero!");
            int256 lagrangeCoefficient = numerator / denominator;
            result += int256(shares[i].y) * lagrangeCoefficient;

        }

        return uint256(result);
    }

    event WinnerDeclared(string names, uint256[] indices, uint256 voteCount);
    // Oylama sonucunu açıklar
    function endVoting() public onlyOwner returns (string memory) {
        require(votingStarted, "Voting not started");
        require(totalVotes >= threshold, "Not enough votes");

        uint256 reconstructedSecret = reconstructSecret();
        require(reconstructedSecret == secret, "Secret reconstruction failed");

        votingStarted = false;

        uint256 winningVoteCount = 0;
        string memory winners;
        uint256[] memory winnerIndices = new uint256[](candidates.length);
        uint256 winnerCount = 0;

 
        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
            }
        }

        // Beraberlik kontrolü yapar
        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].voteCount == winningVoteCount) {
                winnerIndices[winnerCount] = i; 
                winners = string(abi.encodePacked(winners, candidates[i].name, "-"));
                winnerCount++;
            }
        }

        require(winnerCount > 0, "No winners found");
        emit WinnerDeclared(winners, winnerIndices, winningVoteCount);

        return winners;
    }
}
