# 🧠 StacksOracle Pro

**StacksOracle Pro** is a decentralized prediction market protocol on the **Stacks blockchain**, enabling **community-driven Bitcoin price forecasting** using time-locked STX stake pools. Designed with transparency, fairness, and modular governance, the protocol allows users to predict BTC price trends and earn proportional rewards from the shared pool.

---

## 🌐 System Overview

StacksOracle Pro transforms speculative BTC forecasting into a **trustless, programmable, and gamified protocol** built on top of Stacks — Bitcoin’s smart contract layer. Participants stake STX tokens to forecast BTC's price **direction (bullish or bearish)** over a defined block interval. Rewards are distributed based on prediction accuracy, proportional stake, and the outcome resolved by a registered oracle.

### Key Features

* 🕒 **Time-Bound Prediction Rounds**
  Markets are bound to specific block heights, ensuring fair, verifiable timelines.

* 📈 **Directional Forecasting (Bullish/Bearish)**
  Participants stake STX on directional BTC movements within a defined window.

* 🤖 **Oracle-Resolved Market Outcomes**
  Verified by a registered Oracle to ensure outcome correctness and transparency.

* ⚖️ **Fair Reward Distribution**
  Rewards are divided among winners proportionally after a protocol fee is deducted.

* 🛠️ **Admin & Governance Controls**
  Oracle address, protocol fee, and stake thresholds are upgradable by the contract owner.

---

## ⚙️ Contract Architecture

The protocol is implemented as a single Clarity smart contract and modularly structured for clarity and auditability.

### 🔐 Core Constants

```clojure
CONTRACT_OWNER          ;; Protocol administrator (usually the deployer)
ERR_*                   ;; Defined error codes for common failure conditions
```

### 📦 State Variables

* `oracle-principal`: Oracle address authorized to finalize market outcomes.
* `min-stake-threshold`: Minimum amount of STX to participate.
* `protocol-fee-rate`: Fee (%) applied to total winnings.
* `market-sequence`: Auto-incremented market ID counter.

### 🗂️ Data Structures

* **prediction-markets (map)**
  Stores metadata and aggregated stats per market.
* **participant-positions (map)**
  Tracks user participation, direction, stake, and reward status.

---

## 🔁 Contract Flow

### 1. **Market Initialization**

```clojure
(initialize-prediction-market btc-price start-block end-block)
```

Only the `CONTRACT_OWNER` can create new markets with an initial BTC price and duration.

---

### 2. **Prediction Submission**

```clojure
(submit-price-prediction market-id direction stake-amount)
```

Users stake STX and choose `"bullish"` or `"bearish"` before the market's end block. Each participant may stake once per market.

---

### 3. **Market Finalization (Oracle)**

```clojure
(finalize-market-outcome market-id closing-btc-price)
```

Only the `oracle-principal` can resolve a market once its block window closes.

---

### 4. **Reward Claim**

```clojure
(claim-prediction-rewards market-id)
```

Winning participants claim their STX, calculated as:

```
User Share = (userStake / totalWinningStake) * totalPool
Protocol Fee = feeRate * User Share
Net Payout = User Share - Protocol Fee
```

Transfers:

* Net payout → user
* Fee → contract owner

---

### 5. **Admin Controls**

```clojure
(update-oracle-address new-principal)
(adjust-minimum-stake new-min)
(modify-fee-structure new-fee)
(withdraw-protocol-fees amount)
```

Restricted to the `CONTRACT_OWNER`.

---

## 🔄 Optional: Data Flow

```text
[User] 
  → submits stake + prediction 
    → [Contract] validates & stores prediction 
      → updates stake totals

[Oracle] 
  → provides final BTC price 
    → [Contract] finalizes market outcome

[User]
  → claims reward
    → [Contract] calculates payout 
      → transfers STX
```

---

## 📖 Read-Only Functions

| Function                   | Description                           |
| -------------------------- | ------------------------------------- |
| `get-market-details`       | Returns details for a given market ID |
| `get-participant-position` | Returns a user's position in a market |
| `get-protocol-balance`     | STX balance held by the contract      |
| `get-current-parameters`   | Returns oracle, fee, min-stake, etc.  |

---

## 🔐 Security & Best Practices

* ✅ **Oracle Restriction**: Only authorized oracle can resolve markets.
* ✅ **Reward Locking**: Users can’t double-claim rewards.
* ✅ **Fairness Checks**: Ensures timely predictions and minimum stake.
* ✅ **Fee Governance**: Adjustable protocol fee and stake threshold.

---

## 🧪 Future Improvements

* 🧩 Multi-direction markets (e.g., range-bound, volatility)
* 🗳 DAO-based governance of protocol parameters
* 📡 Integration with decentralized BTC oracles (e.g., DLCs)
* 📱 Frontend DApp with market visualization and user dashboards

---

## 📜 License

This protocol is open-source under the MIT License.
