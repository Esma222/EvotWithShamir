# 🔐 Ethereum-Based E-Voting System

A secure electronic voting platform built on the Ethereum blockchain using Solidity and **Shamir's Secret Sharing** for vote privacy.

📄 Detailed scenario and documentation are available in the `/evot/ShamirEvote_presentation.pdf`.

---

## 🧠 Overview
This project aims to create a **transparent, privacy-preserving electronic voting system**.  
By leveraging blockchain technology, it eliminates the need for a centralized authority while ensuring:
- Every vote is recorded permanently.
- No user can vote more than once.
- The final results can be publicly verified.

Traditional e-voting systems often rely on centralized servers, which makes them vulnerable to tampering.  
Here, we use **Ethereum smart contracts** to handle election logic, and **Shamir’s Secret Sharing** to secure voter identities.

---

## ⚙️ Tech Stack
- **Solidity** (Smart contract logic)
- **Remix IDE** (Development & testing)
- **MetaMask** (Wallet & blockchain interaction)
- **SepoliaETH Testnet** (Blockchain network)

---

## 🧩 Features
✅ Voter registration with unique Ethereum addresses  
✅ Prevention of double voting through blockchain validation  
✅ Publicly verifiable and immutable results  
✅ Voters must have a non-zero SepoliaETH balance to participate  
✅ Integration with Shamir’s Secret Sharing for secure vote splitting  

---

## 🚀 How to Run

1. Open [Remix IDE](https://remix.ethereum.org/)  
2. Load the Solidity source code (`.sol` file)  
3. Connect your **MetaMask** wallet to the **Sepolia test network**  
4. Fund accounts with small amounts of SepoliaETH  
5. Deploy the contract and specify the number of voters  
6. Interact with the contract via Remix UI (register, vote, view results)

---

## 🧠 My Learning Notes
- Learned to handle account linking between MetaMask and Remix  
- Implemented **Shamir’s Secret Sharing** to ensure private vote storage  
- Understood **gas consumption optimization** during contract deployment  
- Gained hands-on experience with **testnet-based validation**

---

## 📜 References
- Presented and published at **ISDFS Conference 202X**  
- Related research: [Shamir’s Secret Sharing - Original Paper (1979)](https://ieeexplore.ieee.org/document/11011920)

---

🧩 *This project demonstrates how blockchain and cryptography can work together to ensure democratic transparency without compromising voter privacy.*
