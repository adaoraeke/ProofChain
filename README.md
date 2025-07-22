# ProofChain - Digital Receipts + Warranty System

A blockchain-based digital receipt and warranty management system built on Stacks using Clarinet 2.0+. ProofChain creates immutable, NFT-based receipts with embedded warranty information and automated claim processing.

## 🌟 Features

### Core Functionality
- **NFT-Based Receipts**: Each purchase generates a unique, tamper-proof digital receipt
- **Smart Warranty Clock**: Automated warranty tracking with expiration date encoding
- **Warranty Claims**: Streamlined refund/repair claim processing
- **Merchant Authorization**: Verified merchant system for trusted transactions
- **Ownership Transfer**: Receipts can be transferred (useful for gifts/resales)

### Key Benefits
- ✅ **Immutable Records**: Blockchain-based receipts that cannot be lost or forged
- ✅ **Automated Warranty**: Smart contracts automatically validate warranty periods
- ✅ **Transparent Claims**: All warranty claims are recorded on-chain
- ✅ **Multi-Merchant Support**: Scalable system for multiple retailers
- ✅ **Consumer Protection**: Built-in safeguards against fraud

## 🛠 Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity Smart Contract
- **Framework**: Clarinet 2.0+
- **Standards**: Custom NFT-like implementation for receipts

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) 2.0 or later
- [Stacks CLI](https://docs.hiro.so/stacks-cli)
- Node.js 16+ (for testing)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/proofchain-digital-receipts-stacks.git
   cd proofchain-digital-receipts-stacks
   ```

2. **Initialize Clarinet project**
   ```bash
   clarinet new proofchain
   cd proofchain
   ```

3. **Add the contract**
   ```bash
   # Copy the contract file to contracts/proofchain.clar
   cp ../proofchain.clar contracts/
   ```

4. **Update Clarinet.toml**
   ```toml
   [contracts.proofchain]
   path = "contracts/proofchain.clar"
   ```

### Deployment

#### Local Development
```bash
# Start local devnet
clarinet integrate

# Deploy contract
clarinet deploy --devnet
```

#### Testnet Deployment
```bash
# Deploy to testnet
clarinet deploy --testnet
```

#### Mainnet Deployment
```bash
# Deploy to mainnet (production)
clarinet deploy --mainnet
```

## 📖 Usage Guide

### For Merchants

#### 1. Register as Merchant
```clarity
;; Contract owner registers merchant
(contract-call? .proofchain register-merchant 'SP2MERCHANT... "Electronics Store")
```

#### 2. Issue Digital Receipt
```clarity
;; Issue receipt for customer purchase
(contract-call? .proofchain issue-receipt 
  'SP1CUSTOMER...           ;; Customer address
  "LAPTOP001"               ;; Product ID
  "Gaming Laptop X1"        ;; Product name
  u150000                   ;; Price in microSTX (1500 STX)
  u365                      ;; Warranty period (1 year)
  "manufacturer"            ;; Warranty type
  (some "ipfs://metadata")) ;; Optional metadata URI
```

### For Customers

#### 1. Check Warranty Status
```clarity
;; Check if warranty is still valid
(contract-call? .proofchain check-warranty-status u1)
```

#### 2. Submit Warranty Claim
```clarity
;; Submit claim for repair/refund
(contract-call? .proofchain submit-warranty-claim 
  u1              ;; Receipt ID
  "repair"        ;; Claim type: "repair", "refund", "replacement"
  u50000)         ;; Claim amount in microSTX
```

#### 3. Transfer Receipt
```clarity
;; Transfer receipt to new owner (for resale/gift)
(contract-call? .proofchain transfer-receipt u1 'SP2NEWOWNER...)
```

### For Admins

#### Process Warranty Claims
```clarity
;; Approve or reject warranty claim
(contract-call? .proofchain process-warranty-claim 
  u1           ;; Receipt ID
  u1           ;; Claim ID
  "approved")  ;; Status: "approved", "rejected", "completed"
```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|---------|
| `register-merchant` | Register new authorized merchant | Owner only |
| `issue-receipt` | Create digital receipt NFT | Authorized merchants |
| `transfer-receipt` | Transfer receipt ownership | Receipt owner |
| `submit-warranty-claim` | Submit warranty claim | Receipt owner |
| `process-warranty-claim` | Process pending claims | Merchant/Owner |
| `deactivate-receipt` | Deactivate receipt | Owner/Merchant |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-receipt` | Get receipt details | Receipt data |
| `check-warranty-status` | Check warranty validity | Warranty info |
| `get-warranty-claim` | Get claim details | Claim data |
| `get-merchant-info` | Get merchant details | Merchant data |
| `is-receipt-owner` | Check ownership | Boolean |

## 🛡 Security Features

- **Access Control**: Role-based permissions for merchants, customers, and admins
- **Warranty Validation**: Automatic expiration checking prevents invalid claims
- **Fraud Prevention**: Claims cannot exceed purchase price
- **Immutable Records**: All transactions recorded on blockchain
- **Authorized Merchants**: Only verified merchants can issue receipts

## 🧪 Testing

### Run Tests
```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/proofchain_test.ts
```

### Example Test Cases
- Merchant registration and authorization
- Receipt issuance and validation
- Warranty expiration logic
- Claim submission and processing
- Ownership transfers
- Edge cases and error handling

## 🔍 Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `err-owner-only` | Function restricted to contract owner |
| 101 | `err-not-authorized` | Caller not authorized for this action |
| 102 | `err-receipt-not-found` | Receipt doesn't exist or is inactive |
| 103 | `err-warranty-expired` | Warranty period has expired |
| 104 | `err-invalid-merchant` | Merchant not registered or inactive |
| 105 | `err-invalid-warranty-period` | Warranty period exceeds maximum allowed |
| 106 | `err-claim-already-processed` | Claim has already been processed |
| 107 | `err-insufficient-funds` | Claim amount exceeds purchase price |

## 📊 Data Structures

### Receipt NFT
```clarity
{
  owner: principal,
  merchant: principal,
  product-id: (string-ascii 64),
  product-name: (string-ascii 128),
  purchase-price: uint,
  purchase-timestamp: uint,
  warranty-period-days: uint,
  warranty-type: (string-ascii 32),
  metadata-uri: (optional (string-ascii 256)),
  is-active: bool
}
```

### Warranty Claim
```clarity
{
  claimant: principal,
  claim-type: (string-ascii 32),
  claim-timestamp: uint,
  claim-amount: uint,
  status: (string-ascii 16),
  processor: (optional principal)
}
```

## 🌐 Frontend Integration

### JavaScript/TypeScript Example
```typescript
import { StacksTestnet } from '@stacks/network';
import { makeContractCall } from '@stacks/transactions';

// Issue receipt
const issueReceipt = async () => {
  const txOptions = {
    contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    contractName: 'proofchain',
    functionName: 'issue-receipt',
    functionArgs: [/* function arguments */],
    network: new StacksTestnet(),
    // ... other options
  };
  
  return await makeContractCall(txOptions);
};
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Write comprehensive tests for new features
- Follow Clarity best practices
- Update documentation for API changes
- Ensure all tests pass before submitting PR

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🛟 Support

- **Documentation**: [Clarity Documentation](https://docs.stacks.co/clarity)
- **Issues**: [GitHub Issues](https://github.com/your-username/proofchain-digital-receipts-stacks/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/proofchain-digital-receipts-stacks/discussions)

## 🗺 Roadmap

- [ ] **V1.1**: Multi-signature warranty claims
- [ ] **V1.2**: Integration with existing POS systems
- [ ] **V1.3**: Mobile app for receipt management
- [ ] **V2.0**: Cross-chain compatibility
- [ ] **V2.1**: AI-powered fraud detection
- [ ] **V2.2**: Marketplace for warranty transfers

## 👥 Team

- **Smart Contract Development**: Built with Clarity best practices
- **Security Audits**: Comprehensive testing and validation
- **Documentation**: Complete API and usage documentation

---

**Built with ❤️ using Stacks and Clarinet**

*ProofChain - Making warranties as permanent as the blockchain itself.*
