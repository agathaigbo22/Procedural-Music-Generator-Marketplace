# 🎵 Procedural Music Generator Marketplace

A revolutionary blockchain-based marketplace where users submit prompts to generate AI-created music tracks, minted as NFTs with transparent usage royalties. This platform democratizes music creation for indie producers while ensuring fair compensation through automated licensing.

## ✨ Features

- 🎼 **AI-Generated Music NFTs**: Submit prompts to create unique music tracks minted as NFTs
- 💰 **Automated Royalty System**: Creators receive royalties from secondary sales and licensing
- 🏪 **Decentralized Marketplace**: Buy, sell, and trade music NFTs with transparent pricing
- 📄 **Usage Licensing**: Purchase commercial and personal use licenses for tracks
- 🔒 **Smart Contract Security**: All transactions handled securely on the Stacks blockchain
- 📊 **Earnings Tracking**: Monitor total earnings and royalty balances

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks CLI](https://docs.stacks.co/docs/stacks-cli) (optional)
- STX tokens for transactions

### Installation

```bash
git clone <repository-url>
cd Procedural-Music-Generator-Marketplace
clarinet check
```

## 📖 Contract Functions

### 🎨 Creating Music

#### `mint-music-track`
Create a new AI-generated music NFT.

```clarity
(mint-music-track 
  recipient-principal
  "Create a chill lo-fi beat with rain sounds"  ;; prompt
  "Rainy Day Vibes"                             ;; title
  "lo-fi"                                       ;; genre
  u180                                          ;; duration in seconds
  u500                                          ;; royalty rate (5% = 500/10000)
  (some "https://ipfs.io/metadata/track1")      ;; metadata URI
)
```

### 🛒 Marketplace Operations

#### `list-for-sale`
List your music NFT for sale.

```clarity
(list-for-sale u1 u5000000) ;; List token #1 for 5 STX
```

#### `buy-track`
Purchase a listed music NFT.

```clarity
(buy-track u1) ;; Buy token #1
```

#### `cancel-listing`
Remove your NFT from the marketplace.

```clarity
(cancel-listing u1) ;; Cancel listing for token #1
```

### 📄 Licensing System

#### `purchase-license`
Buy usage rights for a music track.

```clarity
;; Personal license (1 STX base price)
(purchase-license u1 "personal" none)

;; Commercial license (5 STX) with 1000 block expiration
(purchase-license u1 "commercial" (some u1000))
```

### 📊 Query Functions

#### Track Information
```clarity
(get-track-info u1)           ;; Get track metadata
(get-track-owner u1)          ;; Get current owner
(get-total-earnings u1)       ;; Get track's total earnings
```

#### Market Data
```clarity
(get-market-listing u1)       ;; Get listing details
(get-last-token-id)           ;; Get latest token ID
```

#### User Data
```clarity
(get-royalty-balance principal) ;; Check royalty earnings
(get-license-info u1 principal) ;; Check license status
(has-valid-license u1 principal) ;; Verify active license
```

## 💎 Business Model

### 🏦 Fee Structure
- **Platform Fee**: 2.5% of all sales (adjustable by contract owner)
- **Creator Royalties**: Set by creator (0-10% of sales)
- **License Pricing**:
  - Personal Use: 1 STX base price
  - Commercial Use: 5x base price

### 💸 Revenue Streams
1. **Primary Sales**: Direct NFT purchases
2. **Secondary Sales**: Royalties from resales
3. **License Fees**: Usage rights for existing tracks
4. **Platform Fees**: Small percentage from all transactions

## 🔧 Advanced Usage

### Setting Custom Royalties
When minting, set royalty rates as basis points (100 = 1%):
```clarity
u0    ;; 0% royalties
u250  ;; 2.5% royalties
u1000 ;; 10% royalties (maximum)
```

### License Types
- `"personal"`: Personal, non-commercial use
- `"commercial"`: Commercial use in projects
- Custom license types accepted (up to 32 characters)

### Time-based Licenses
Specify license duration in blocks:
```clarity
u144      ;; ~1 day (assuming 10min blocks)
u1008     ;; ~1 week
u4320     ;; ~1 month
```

## 🛡️ Security Features

- ✅ Owner-only functions for sensitive operations
- ✅ Input validation for all parameters  
- ✅ Protection against self-transfers
- ✅ Automatic royalty distribution
- ✅ License expiration tracking

## 📈 Analytics & Insights

Track performance metrics:
- Total tracks created
- Volume traded
- Top-earning tracks
- Creator earnings
- License revenue

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Write tests for new functionality
4. Ensure `clarinet check` passes
5. Submit a pull request

## 📋 Testing

```bash
npm install
npm test
```

Run specific test suites:
```bash
npm run test:unit      ;; Unit tests
npm run test:integration ;; Integration tests
```

## 🐛 Known Issues

- License validation requires manual checking
- Metadata storage handled off-chain
- Gas optimization opportunities exist

## 📞 Support

- 📚 [Documentation](https://docs.stacks.co)
- 💬 [Discord Community](https://discord.gg/stacks)
- 🐛 [Report Issues](https://github.com/your-repo/issues)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🚨 Disclaimer

This smart contract is provided as-is for educational and development purposes. Users should conduct thorough testing before deploying to mainnet. The creators assume no liability for any losses incurred through contract usage.

---

*Built with ❤️ on Stacks blockchain*
