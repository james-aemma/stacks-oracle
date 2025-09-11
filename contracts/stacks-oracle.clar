;; TITLE: StacksOracle Pro - Decentralized Bitcoin Forecasting Engine
;;
;; SUMMARY:
;; A sophisticated prediction protocol built on Stacks blockchain that enables 
;; community-driven Bitcoin price forecasting through time-locked stake pools. 
;; Participants compete in prediction rounds by staking STX tokens on directional 
;; BTC movements, with winners earning proportional rewards from the total pool.
;;
;; DESCRIPTION:
;; StacksOracle Pro transforms Bitcoin price speculation into a structured, 
;; transparent prediction marketplace. Users stake STX tokens to forecast whether 
;; Bitcoin will trend upward or downward within specified block intervals. The 
;; protocol leverages Stacks' unique position as Bitcoin's smart contract layer 
;; to create trustless prediction markets with oracle-verified outcomes. Each 
;; market operates as an isolated pool where accurate forecasters earn rewards 
;; proportional to their stake and prediction accuracy. The system incorporates 
;; dynamic fee structures, configurable parameters, and robust governance 
;; mechanisms to ensure sustainable operation and fair reward distribution.
;;

;; PROTOCOL CONSTANTS & ERROR DEFINITIONS

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MARKET_NOT_FOUND (err u101))
(define-constant ERR_INVALID_PREDICTION (err u102))
(define-constant ERR_MARKET_INACTIVE (err u103))
(define-constant ERR_REWARD_CLAIMED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_INVALID_PARAMS (err u106))
(define-constant ERR_ORACLE_RESTRICTED (err u107))

;; PROTOCOL STATE VARIABLES

(define-data-var oracle-principal principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var min-stake-threshold uint u1000000) ;; 1 STX minimum
(define-data-var protocol-fee-rate uint u2) ;; 2% protocol fee
(define-data-var market-sequence uint u0) ;; Market ID counter

;; MARKET DATA STRUCTURES

(define-map prediction-markets
  uint ;; market-id
  {
    initial-btc-price: uint,
    final-btc-price: uint,
    bullish-stake-total: uint,
    bearish-stake-total: uint,
    market-start-height: uint,
    market-end-height: uint,
    is-resolved: bool,
  }
)

(define-map participant-positions
  {
    market-id: uint,
    participant: principal,
  }
  {
    price-direction: (string-ascii 8),
    staked-amount: uint,
    rewards-claimed: bool,
  }
)

;; MARKET CREATION & MANAGEMENT

(define-public (initialize-prediction-market
    (btc-opening-price uint)
    (start-block-height uint)
    (end-block-height uint)
  )
  (let ((new-market-id (var-get market-sequence)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> end-block-height start-block-height) ERR_INVALID_PARAMS)
    (asserts! (> btc-opening-price u0) ERR_INVALID_PARAMS)

    (map-set prediction-markets new-market-id {
      initial-btc-price: btc-opening-price,
      final-btc-price: u0,
      bullish-stake-total: u0,
      bearish-stake-total: u0,
      market-start-height: start-block-height,
      market-end-height: end-block-height,
      is-resolved: false,
    })

    (var-set market-sequence (+ new-market-id u1))
    (ok new-market-id)
  )
)

;; PREDICTION SUBMISSION & STAKE MANAGEMENT

(define-public (submit-price-prediction
    (market-id uint)
    (direction (string-ascii 8))
    (stake-amount uint)
  )
  (let (
      (market-data (unwrap! (map-get? prediction-markets market-id) ERR_MARKET_NOT_FOUND))
      (current-height stacks-block-height)
    )
    ;; Validate market timing and status
    (asserts!
      (and
        (>= current-height (get market-start-height market-data))
        (< current-height (get market-end-height market-data))
      )
      ERR_MARKET_INACTIVE
    )

    ;; Validate prediction parameters
    (asserts! (or (is-eq direction "bullish") (is-eq direction "bearish"))
      ERR_INVALID_PREDICTION
    )
    (asserts! (>= stake-amount (var-get min-stake-threshold))
      ERR_INVALID_PREDICTION
    )
    (asserts! (<= stake-amount (stx-get-balance tx-sender))
      ERR_INSUFFICIENT_FUNDS
    )

    ;; Process stake transfer
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))

    ;; Record participant position
    (map-set participant-positions {
      market-id: market-id,
      participant: tx-sender,
    } {
      price-direction: direction,
      staked-amount: stake-amount,
      rewards-claimed: false,
    })

    ;; Update market totals
    (map-set prediction-markets market-id
      (merge market-data {
        bullish-stake-total: (if (is-eq direction "bullish")
          (+ (get bullish-stake-total market-data) stake-amount)
          (get bullish-stake-total market-data)
        ),
        bearish-stake-total: (if (is-eq direction "bearish")
          (+ (get bearish-stake-total market-data) stake-amount)
          (get bearish-stake-total market-data)
        ),
      })
    )

    (ok true)
  )
)

;; ORACLE INTEGRATION & MARKET RESOLUTION

(define-public (finalize-market-outcome
    (market-id uint)
    (btc-closing-price uint)
  )
  (let ((market-data (unwrap! (map-get? prediction-markets market-id) ERR_MARKET_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get oracle-principal)) ERR_ORACLE_RESTRICTED)
    (asserts! (>= stacks-block-height (get market-end-height market-data))
      ERR_MARKET_INACTIVE
    )
    (asserts! (not (get is-resolved market-data)) ERR_MARKET_INACTIVE)
    (asserts! (> btc-closing-price u0) ERR_INVALID_PARAMS)

    (map-set prediction-markets market-id
      (merge market-data {
        final-btc-price: btc-closing-price,
        is-resolved: true,
      })
    )

    (ok true)
  )
)

;; REWARD CALCULATION & DISTRIBUTION

(define-public (claim-prediction-rewards (market-id uint))
  (let (
      (market-data (unwrap! (map-get? prediction-markets market-id) ERR_MARKET_NOT_FOUND))
      (participant-data (unwrap!
        (map-get? participant-positions {
          market-id: market-id,
          participant: tx-sender,
        })
        ERR_MARKET_NOT_FOUND
      ))
    )
    ;; Validate claim eligibility
    (asserts! (get is-resolved market-data) ERR_MARKET_INACTIVE)
    (asserts! (not (get rewards-claimed participant-data)) ERR_REWARD_CLAIMED)

    (let (
        (winning-direction (if (> (get final-btc-price market-data)
            (get initial-btc-price market-data)
          )
          "bullish"
          "bearish"
        ))
        (total-pool (+ (get bullish-stake-total market-data)
          (get bearish-stake-total market-data)
        ))
        (winning-pool-size (if (is-eq winning-direction "bullish")
          (get bullish-stake-total market-data)
          (get bearish-stake-total market-data)
        ))
      )
      ;; Verify participant backed winning direction
      (asserts! (is-eq (get price-direction participant-data) winning-direction)
        ERR_INVALID_PREDICTION
      )

      (let (
          (gross-rewards (/ (* (get staked-amount participant-data) total-pool)
            winning-pool-size
          ))
          (protocol-fee (/ (* gross-rewards (var-get protocol-fee-rate)) u100))
          (net-payout (- gross-rewards protocol-fee))
        )
        ;; Execute reward transfers
        (try! (as-contract (stx-transfer? net-payout (as-contract tx-sender) tx-sender)))
        (try! (as-contract (stx-transfer? protocol-fee (as-contract tx-sender) CONTRACT_OWNER)))

        ;; Mark rewards as claimed
        (map-set participant-positions {
          market-id: market-id,
          participant: tx-sender,
        }
          (merge participant-data { rewards-claimed: true })
        )

        (ok net-payout)
      )
    )
  )
)

;; READ-ONLY DATA ACCESS FUNCTIONS

(define-read-only (get-market-details (market-id uint))
  (map-get? prediction-markets market-id)
)

(define-read-only (get-participant-position
    (market-id uint)
    (participant principal)
  )
  (map-get? participant-positions {
    market-id: market-id,
    participant: participant,
  })
)

(define-read-only (get-protocol-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-current-parameters)
  {
    oracle: (var-get oracle-principal),
    min-stake: (var-get min-stake-threshold),
    fee-rate: (var-get protocol-fee-rate),
    market-count: (var-get market-sequence),
  }
)

;; ADMINISTRATIVE CONTROL FUNCTIONS

(define-public (update-oracle-address (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (var-set oracle-principal new-oracle))
  )
)

(define-public (adjust-minimum-stake (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-minimum u0) ERR_INVALID_PARAMS)
    (ok (var-set min-stake-threshold new-minimum))
  )
)

(define-public (modify-fee-structure (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-rate u100) ERR_INVALID_PARAMS)
    (ok (var-set protocol-fee-rate new-fee-rate))
  )
)

(define-public (withdraw-protocol-fees (withdrawal-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= withdrawal-amount (stx-get-balance (as-contract tx-sender)))
      ERR_INSUFFICIENT_FUNDS
    )
    (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) CONTRACT_OWNER)))
    (ok withdrawal-amount)
  )
)
