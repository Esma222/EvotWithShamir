// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ShamirVoting {
    uint256 private secret; // Sır
    uint256[] private coefficients; // Rastgele katsayılar

    struct Share {
        uint256 x;
        uint256 y;
    }

    struct Voter {
        bool hasVoted;
        Share share;
        address addr;
    }

    struct Candidate {
        string name;
        uint256 voteCount;
    }

    Candidate[] public candidates;
    Share[] public shares;
    mapping(address => Voter) public voters;
    uint256 public requiredVotes;
    uint256 public totalVotes;
    uint256 public threshold;
    bool public votingStarted;

    mapping(uint256 => string) public shareHashes; // IPFS hash'leri için mapping
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(
        uint256 _threshold, 
        string[] memory candidateNames, 
        address[] memory voterAddresses
    ) {
        require(_threshold > 1, "Threshold must be greater than 1");
        require(_threshold % 2 == 1, "Threshold must be an odd number");
        require(candidateNames.length > 0, "At least one candidate required");
        require(voterAddresses.length > 0, "At least one voter required");

        threshold = _threshold;
        votingStarted = false;
        owner = msg.sender;

        // Adayların eklenmesi
        for (uint256 i = 0; i < candidateNames.length; i++) {
            candidates.push(Candidate({name: candidateNames[i], voteCount: 0}));
        }

        // Oy kullanacak kişilerin eklenmesi
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            voters[voterAddresses[i]] = Voter(false, Share(0, 0), voterAddresses[i]);
        }

        requiredVotes = voterAddresses.length;
        // Sır oluştur ve payları dağıt
        generateSecretAndShares(voterAddresses);
    }

    // Rastgele bir sayı üretir (basit bir yerel rastgele sayı üretici)
    function random() internal view returns (uint256) {
        return uint(keccak256(abi.encodePacked(block.timestamp))) % 100;
    }
   
    // Polinomun katsayılarını, sırrı ve sır paylarını oluşturur
    function generateSecretAndShares(address[] memory voterAddresses) private {
        secret = random();
        // Polinomun katsayılarını rastgele oluşturuyoruz
        coefficients.push(secret);  // Polinomun sabiti (sır)
        for (uint256 i = 1; i < threshold; i++) {
            coefficients.push(random());  // Rastgele katsayılar
        }

       

        for (uint256 i = 0; i < voterAddresses.length; i++) {
            uint256 x = i + 1;
            uint256 y = evaluatePolynomial(x);
            voters[voterAddresses[i]].share = Share(x, y);
        }
    }

  // IPFS hash'lerini kaydetme
    function saveShareHash(uint256 index, string memory ipfsHash) public onlyOwner {
        shareHashes[index] = ipfsHash;
    }

    // IPFS hash'ini görüntüleme
    function getShareHash(uint256 index) public view returns (string memory) {
        return shareHashes[index];
    }

    // Polinomu değerlendirir (sırrı paylaştırma işlemi)
    function evaluatePolynomial(uint256 x) public view returns (uint256) {
        uint256 result = coefficients[0];
        uint256 power = 1;

        // Polinomu hesapla: P(x) = a0 + a1*x + a2*x^2 + ... an*x^n
        for (uint256 i = 1; i < coefficients.length; i++) {
            power *= x;  // x'in üstünü artır
            result += coefficients[i] * power;
        }

        return result;
    }

    // Oylamayı başlatır
    function startVoting() public onlyOwner {
        require(!votingStarted, "Voting already started");
        votingStarted = true;
    }

    // Oy kullanma
    function vote(uint256 candidateIndex, uint256 _x, uint256 _y) public {
        require(votingStarted, "Voting not started");
        require(candidateIndex < candidates.length, "Invalid candidate");
        require(!voters[msg.sender].hasVoted, "Already voted");

        Voter storage voter = voters[msg.sender];
        require(voter.share.x == _x && voter.share.y == _y, "Invalid share");
        shares.push(Share({x: _x, y: _y}));
        voters[msg.sender].hasVoted = true;
        candidates[candidateIndex].voteCount += 1;
        totalVotes += 1;
    }

     // Sırrı geri elde etmek için Lagrange İnterpolasyonu uygular
    function reconstructSecret() public view returns (uint256) {
        require(shares.length > 0, "Shares list is empty");
        int256 result = 0;

        // Lagrange İnterpolasyonu ile sırrı geri elde et
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

    // Sırrı sadece kontrat sahibi tarafından görüntülenebilir
    function getSecret() public view onlyOwner returns (uint256) {
       return secret;
    } 
    event WinnerDeclared(string name, uint256 index, uint256 voteCount);
    // Oylama sonucunu açıklar
    function endVoting() public onlyOwner returns (string memory) {
        require(votingStarted, "Voting not started");
        require(totalVotes >= threshold, "Not enough votes");

        uint256 reconstructedSecret = reconstructSecret();
        require(reconstructedSecret == secret, "Secret reconstruction failed");

        votingStarted = false;

        uint256 winningVoteCount = 0;
        string memory winner;
        uint256 winnerIndex;

        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winner = candidates[i].name;
                winnerIndex = i;
            }
        }

       // Kazanan bilgilerini event ile yayınla
       emit WinnerDeclared(winner, winnerIndex, winningVoteCount);

       return winner;
    }
}
