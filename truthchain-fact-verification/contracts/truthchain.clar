;; TruthChain - Crowdsourced fact-checking for AI claims
;; Reviewers verify claims and earn rewards for accurate verification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-verified (err u102))
(define-constant err-invalid-score (err u103))
(define-constant err-claim-finalized (err u104))

;; Data vars
(define-data-var claim-nonce uint u0)
(define-data-var verification-threshold uint u3)

;; Data maps
(define-map claims
    { claim-id: uint }
    {
        submitter: principal,
        claim-text: (string-ascii 500),
        truth-score: uint,
        verification-count: uint,
        status: (string-ascii 20),
        reward-pool: uint
    }
)

(define-map verifications
    { claim-id: uint, verifier: principal }
    { score: uint, timestamp: uint }
)

(define-map verifier-stats
    { verifier: principal }
    { total-verifications: uint, accuracy-score: uint }
)