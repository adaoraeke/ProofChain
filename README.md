# ProofChain - Digital Receipts + Warranty

This repository contains the Clarity smart contract for ProofChain, a system designed to issue unique, NFT-based digital receipts with embedded smart warranty clocks on the Stacks blockchain.

## 🚀 Key Functional Features

### NFT-Based Receipts
Each successful sale issues a unique Non-Fungible Token (NFT) receipt. This NFT serves as an immutable, verifiable proof of purchase.
- **Timestamp:** The block height at which the receipt was minted is embedded, providing a precise record of the sale date.
- **Product ID:** A unique identifier for the purchased product is stored within the NFT.
- **Merchant ID:** The principal address of the merchant who issued the receipt is recorded.

### Smart Warranty Clock
Each NFT receipt includes a built-in warranty mechanism.
- **Expiry Date Encoded:** A `warranty-expiry-block` (block height) is encoded into the NFT at the time of minting.
- **Trigger Options:** The contract provides a read-only function to check if the warranty is still valid based on the current block height. This status can then be used by off-chain applications to trigger refund or repair options if the warranty is active.

## 💡 Contract Details

- **Contract Name:** `proofchain-receipts.clar`
- **Purpose:** To provide a decentralized, transparent, and verifiable system for digital receipts and product warranties.

## 🛠️ How to Use

This contract is built using Clarity and can be deployed and interacted with on the Stacks blockchain. We recommend using Clarinet for local development and testing.

### Prerequisites
- [Clarinet](https://docs.stacks.co/clarity/clarinet) installed on your system.

### Local Development with Clarinet

1.  **Create a new Clarinet project:**
    \`\`\`bash
    clarinet new proofchain-clarity-contract
    cd proofchain-clarity-contract
    \`\`\`

2.  **Replace the default contract:**
    Delete the `contracts/counter.clar` file and create a new file named `contracts/proofchain-receipts.clar`. Copy the Clarity code provided into this new file.

3.  **Start a Clarinet development environment:**
    \`\`\`bash
    clarinet integrate
    \`\`\`
    This will start a local blockchain instance.

4.  **Deploy the contract (in a new terminal):**
    \`\`\`bash
    clarinet deploy
    \`\`\`
    This will deploy `proofchain-receipts.clar` to your local blockchain.

5.  **Interact with the contract:**
    You can use `clarinet console` or `clarinet call` to interact with the deployed contract. The default deployer principal in Clarinet is `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM`.

    **Example Interactions:**

    *   **Mint a new receipt:**
        \`\`\`bash
        clarinet call proofchain-receipts mint-receipt '(u1001 .principal "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM" u100)' --sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
        # Arguments: product-id (u1001), merchant-id (ST1PQ...), warranty-duration-in-blocks (u100)
        # The sender of the transaction will be the initial owner of the NFT receipt.
        \`\`\`

    *   **Get receipt details:**
        \`\`\`bash
        clarinet call proofchain-receipts get-receipt-details '(u1)'
        # Argument: token-id (u1)
        \`\`\`

    *   **Check warranty status:**
        \`\`\`bash
        clarinet call proofchain-receipts check-warranty-status '(u1)'
        # Argument: token-id (u1)
        \`\`\`

    *   **Get the owner of a receipt:**
        \`\`\`bash
        clarinet call proofchain-receipts get-owner '(u1)'
        # Argument: token-id (u1)
        \`\`\`

    *   **Transfer a receipt:**
        \`\`\`bash
        clarinet call proofchain-receipts transfer '(u1 .principal "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM" .principal "ST2CY5V39NHDPWSX69WMGMV7X6DGFJXYK3ATYJ000")' --sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
        # Arguments: token-id (u1), sender (ST1PQ...), recipient (ST2CY...)
        # Note: Replace ST2CY5V39NHDPWSX69WMGMV7X6DGFJXYK3ATYJ000 with another valid test principal from your Clarinet environment.
        \`\`\`

### Error Codes

The contract defines the following error codes:

-   \`u100\`: \`ERR-NOT-AUTHORIZED\` - The transaction sender is not authorized to perform the action (if access control is implemented).
-   \`u101\`: \`ERR-INVALID-TOKEN-ID\` - The provided token ID is invalid (used by SIP-009 trait functions).
-   \`u103\`: \`ERR-RECEIPT-NOT-FOUND\` - The receipt with the given token ID does not exist.

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
