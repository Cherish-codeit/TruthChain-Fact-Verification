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

;; Read-only functions
(define-read-only (get-claim (claim-id uint))
    (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-verification (claim-id uint) (verifier principal))
    (map-get? verifications { claim-id: claim-id, verifier: verifier })
)

(define-read-only (get-verifier-stats (verifier principal))
    (map-get? verifier-stats { verifier: verifier })
)

(define-read-only (get-claim-nonce)
    (ok (var-get claim-nonce))
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (submit-claim (claim-text (string-ascii 500)) (reward-pool uint))
    (let
        (
            (new-claim-id (+ (var-get claim-nonce) u1))
        )
        (try! (stx-transfer? reward-pool tx-sender (as-contract tx-sender)))
        (map-set claims
            { claim-id: new-claim-id }
            {
                submitter: tx-sender,
                claim-text: claim-text,
                truth-score: u0,
                verification-count: u0,
                status: "pending",
                reward-pool: reward-pool
            }
        )
        (var-set claim-nonce new-claim-id)
        (ok new-claim-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (verify-claim (claim-id uint) (score uint))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
            (current-count (get verification-count claim))
            (current-score (get truth-score claim))
        )
        (asserts! (is-none (map-get? verifications { claim-id: claim-id, verifier: tx-sender })) err-already-verified)
        (asserts! (is-eq (get status claim) "pending") err-claim-finalized)
        (asserts! (<= score u100) err-invalid-score)
        (map-set verifications
            { claim-id: claim-id, verifier: tx-sender }
            { score: score, timestamp: stacks-block-height }
        )
        (map-set claims
            { claim-id: claim-id }
            (merge claim {
                truth-score: (/ (+ (* current-score current-count) score) (+ current-count u1)),
                verification-count: (+ current-count u1)
            })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (finalize-claim (claim-id uint))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
        )
        (asserts! (>= (get verification-count claim) (var-get verification-threshold)) err-invalid-score)
        (asserts! (is-eq (get status claim) "pending") err-claim-finalized)
        (map-set claims
            { claim-id: claim-id }
            (merge claim { status: "finalized" })
        )
        (ok true)
    )
)

(define-public (distribute-rewards (claim-id uint))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
            (total-pool (get reward-pool claim))
            (reward-per-verifier (/ total-pool (get verification-count claim)))
        )
        (asserts! (is-eq (get status claim) "finalized") err-claim-finalized)
        (asserts! (> (get verification-count claim) u0) err-invalid-score)
        (ok reward-per-verifier)
    )
)

(define-public (claim-reward (claim-id uint))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
            (verification (unwrap! (map-get? verifications { claim-id: claim-id, verifier: tx-sender }) err-not-found))
            (total-pool (get reward-pool claim))
            (reward-amount (/ total-pool (get verification-count claim)))
        )
        (asserts! (is-eq (get status claim) "finalized") err-claim-finalized)
        (try! (as-contract (stx-transfer? reward-amount tx-sender (unwrap-panic (some tx-sender)))))
        (ok reward-amount)
    )
)

;; #[allow(unchecked_data)]
(define-public (update-verifier-accuracy (verifier principal) (accuracy uint))
    (let
        (
            (stats (default-to 
                { total-verifications: u0, accuracy-score: u0 }
                (map-get? verifier-stats { verifier: verifier })
            ))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= accuracy u100) err-invalid-score)
        (map-set verifier-stats
            { verifier: verifier }
            (merge stats { accuracy-score: accuracy })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (challenge-claim (claim-id uint) (reason (string-ascii 200)))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
        )
        (asserts! (is-eq (get status claim) "finalized") err-claim-finalized)
        (map-set claims
            { claim-id: claim-id }
            (merge claim { status: "disputed" })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (resolve-dispute (claim-id uint) (final-status (string-ascii 20)))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status claim) "disputed") err-claim-finalized)
        (map-set claims
            { claim-id: claim-id }
            (merge claim { status: final-status })
        )
        (ok true)
    )
)

(define-public (update-verification-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-threshold u0) err-invalid-score)
        (var-set verification-threshold new-threshold)
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (withdraw-claim (claim-id uint))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
            (reward-pool (get reward-pool claim))
        )
        (asserts! (is-eq tx-sender (get submitter claim)) err-owner-only)
        (asserts! (is-eq (get status claim) "pending") err-claim-finalized)
        (asserts! (is-eq (get verification-count claim) u0) err-already-verified)
        (try! (as-contract (stx-transfer? reward-pool tx-sender (get submitter claim))))
        (map-set claims
            { claim-id: claim-id }
            (merge claim { status: "withdrawn" })
        )
        (ok reward-pool)
    )
)

;; #[allow(unchecked_data)]
(define-public (update-claim-status (claim-id uint) (new-status (string-ascii 20)))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set claims
            { claim-id: claim-id }
            (merge claim { status: new-status })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (boost-reward-pool (claim-id uint) (additional-amount uint))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
        )
        (asserts! (is-eq (get status claim) "pending") err-claim-finalized)
        (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
        (map-set claims
            { claim-id: claim-id }
            (merge claim { reward-pool: (+ (get reward-pool claim) additional-amount) })
        )
        (ok true)
    )
)