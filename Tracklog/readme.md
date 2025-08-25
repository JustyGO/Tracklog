# 🎨 Masterpiece NFT Gallery

This project is a **Clarity smart contract** that implements a decentralized **art gallery** for managing, exhibiting, and trading unique digital masterpieces as **non-fungible tokens (NFTs)** on the Stacks blockchain.

It supports:

* Creating NFTs with built-in artist commission logic
* Exhibiting artworks in the gallery at a chosen price
* Updating or removing exhibitions with safeguards
* Acquiring artworks with automatic commission distribution
* Gifting artworks between collectors
* Administrative gallery management (curator role, maintenance mode)



## 📜 Features

### 🔹 NFT Creation

* Each artwork (`masterpiece-id`) is minted as a **unique NFT**.
* The original artist defines a **commission rate** (up to 25%) that applies to all future sales.

### 🔹 Exhibitions

* Owners can **exhibit** their masterpiece at a chosen price (within allowed limits).
* Exhibitions can be **updated** but only once every **24 hours**.
* Artworks can be **removed** from exhibitions at any time.

### 🔹 Acquisition

* Collectors can acquire exhibited masterpieces by paying the exhibition price.
* The contract automatically splits payment:

  * A commission goes to the **original artist**.
  * The remainder goes to the **current owner**.
* NFT ownership is transferred securely to the collector.

### 🔹 Gifting

* Owners may **gift artworks** directly to another wallet.

### 🔹 Governance & Maintenance

* The **gallery owner** can appoint a **curator**.
* The curator can toggle **maintenance mode** (pausing all core functions).

---

## ⚖️ Constants & Limits

| Constant                  | Value                | Description                          |
| ------------------------- | -------------------- | ------------------------------------ |
| `ARTWORK_MIN_PRICE`       | `1 µSTX`             | Minimum exhibition price             |
| `ARTWORK_MAX_PRICE`       | `1,000,000,000 µSTX` | Maximum exhibition price (1,000 STX) |
| `MAX_COMMISSION_RATE`     | `25%`                | Maximum artist commission            |
| `EXHIBITION_UPDATE_DELAY` | `86400 blocks`       | 24-hour delay before price updates   |
| `MAX_MASTERPIECE_ID`      | `1,000,000`          | Maximum NFT supply                   |

---

## 🚨 Error Codes

| Code    | Meaning                                               |
| ------- | ----------------------------------------------------- |
| `u101`  | Artwork not exhibited                                 |
| `u102`  | Insufficient balance                                  |
| `u103`  | Acquisition failed                                    |
| `u104`  | Invalid commission                                    |
| `u105`  | Access denied                                         |
| `u106`  | Cannot acquire/gift to self                           |
| `u107`  | Invalid exhibition price                              |
| `u108`  | Exhibition price update too soon                      |
| `u109`  | Gallery under maintenance                             |
| `u110`  | Artwork already exhibited                             |
| `u111`  | Invalid masterpiece ID                                |
| `u112`  | Invalid curator appointment                           |
| `u300+` | NFT-specific errors (minting, ownership checks, etc.) |


## 🛠️ Public Functions

### Artwork Lifecycle

* `create-masterpiece (piece-id uint) (commission-rate uint)` → Mint a new NFT
* `exhibit-artwork (piece-id uint) (exhibition-price uint)` → List for sale
* `update-exhibition-price (piece-id uint) (new-price uint)` → Change price (24h cooldown)
* `remove-from-exhibition (piece-id uint)` → Remove from gallery
* `acquire-masterpiece (piece-id uint)` → Buy exhibited artwork
* `gift-masterpiece (piece-id uint) (recipient principal)` → Gift to another user

### Gallery Administration

* `set-gallery-curator (new-curator principal)` → Appoint curator
* `toggle-gallery-maintenance` → Enable/disable maintenance mode

### Read-Only Queries

* `is-artwork-exhibited (piece-id uint)` → Check exhibition status
* `get-exhibition-details (piece-id uint)` → Retrieve exhibition details
* `get-artist-commission-info (piece-id uint)` → Get commission info
* `calculate-artist-commission (price uint) (rate uint)` → Compute commission


## 🖼️ Example Flow

1. **Artist** creates a masterpiece:

   ```clarity
   (contract-call? .gallery create-masterpiece u1 u10) ;; 10% commission
   ```

2. **Artist** exhibits it for sale:

   ```clarity
   (contract-call? .gallery exhibit-artwork u1 u1000000) ;; 1 STX
   ```

3. **Collector** acquires it:

   ```clarity
   (contract-call? .gallery acquire-masterpiece u1)
   ```

4. Funds are split:

   * 10% to original artist
   * 90% to seller (previous owner)


## 🔑 Roles

* **Gallery Owner**: Contract deployer, can appoint curator.
* **Curator**: Can toggle maintenance mode.
* **Artist**: Original NFT creator, receives commissions.
* **Collector**: Anyone acquiring or gifting artworks.


## 📂 Project Structure

```
/contracts
  └── gallery.clar   # Main Clarity smart contract
README.md             # Documentation
```
