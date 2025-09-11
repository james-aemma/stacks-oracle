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