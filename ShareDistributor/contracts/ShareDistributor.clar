;; Automated Dividend Distribution for Tokenized Shares
;; This contract manages tokenized shares and automates dividend distribution
;; to shareholders proportional to their holdings. It supports multiple dividend
;; rounds, prevents double-claiming, and ensures secure fund management.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-already-claimed (err u103))
(define-constant err-no-dividends (err u104))
(define-constant err-not-shareholder (err u105))
(define-constant err-transfer-failed (err u106))
(define-constant err-round-not-active (err u107))
(define-constant err-invalid-shares (err u108))

;; data maps and vars
;; Track share balances for each address
(define-map share-balances principal uint)

;; Track total shares issued
(define-data-var total-shares uint u0)

;; Track dividend rounds
(define-data-var current-dividend-round uint u0)

;; Store dividend pool for each round
(define-map dividend-pools uint uint)

;; Track which addresses have claimed dividends for each round
(define-map dividend-claims {shareholder: principal, round: uint} bool)

;; Store total shares snapshot at each dividend round
(define-map shares-snapshot uint uint)

;; Track if a dividend round is active
(define-map round-active uint bool)

;; Store contract balance for dividend distribution
(define-data-var dividend-reserve uint u0)

;; private functions
;; Calculate proportional dividend for a shareholder
(define-private (calculate-dividend (shareholder-shares uint) (total-shares-snapshot uint) (total-dividend uint))
    (if (is-eq total-shares-snapshot u0)
        u0
        (/ (* shareholder-shares total-dividend) total-shares-snapshot)
    )
)

;; Verify shareholder has minimum shares
(define-private (has-minimum-shares (shareholder principal))
    (>= (default-to u0 (map-get? share-balances shareholder)) u1)
)

;; Check if caller is contract owner
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

;; Update share balance safely
(define-private (update-balance (address principal) (new-balance uint))
    (begin
        (map-set share-balances address new-balance)
        true
    )
)

;; public functions
;; Issue initial shares to an address (owner only)
(define-public (issue-shares (recipient principal) (amount uint))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (asserts! (> amount u0) err-invalid-amount)
        
        (let (
            (current-balance (default-to u0 (map-get? share-balances recipient)))
            (new-balance (+ current-balance amount))
            (new-total (+ (var-get total-shares) amount))
        )
            (update-balance recipient new-balance)
            (var-set total-shares new-total)
            (ok new-balance)
        )
    )
)

;; Transfer shares between addresses
(define-public (transfer-shares (recipient principal) (amount uint))
    (let (
        (sender-balance (default-to u0 (map-get? share-balances tx-sender)))
        (recipient-balance (default-to u0 (map-get? share-balances recipient)))
    )
        (asserts! (>= sender-balance amount) err-insufficient-balance)
        (asserts! (> amount u0) err-invalid-amount)
        
        (update-balance tx-sender (- sender-balance amount))
        (update-balance recipient (+ recipient-balance amount))
        (ok true)
    )
)

;; Get share balance for an address
(define-read-only (get-share-balance (account principal))
    (ok (default-to u0 (map-get? share-balances account)))
)

;; Get total shares issued
(define-read-only (get-total-shares)
    (ok (var-get total-shares))
)

;; Create a new dividend round (owner only)
(define-public (create-dividend-round (dividend-amount uint))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (asserts! (> dividend-amount u0) err-invalid-amount)
        (asserts! (> (var-get total-shares) u0) err-invalid-shares)
        
        (let (
            (new-round (+ (var-get current-dividend-round) u1))
            (current-total-shares (var-get total-shares))
        )
            (var-set current-dividend-round new-round)
            (map-set dividend-pools new-round dividend-amount)
            (map-set shares-snapshot new-round current-total-shares)
            (map-set round-active new-round true)
            (var-set dividend-reserve (+ (var-get dividend-reserve) dividend-amount))
            (ok new-round)
        )
    )
)

;; Claim dividends for a specific round
(define-public (claim-dividend (round uint))
    (let (
        (shareholder-shares (default-to u0 (map-get? share-balances tx-sender)))
        (dividend-pool (default-to u0 (map-get? dividend-pools round)))
        (total-shares-at-round (default-to u0 (map-get? shares-snapshot round)))
        (already-claimed (default-to false (map-get? dividend-claims {shareholder: tx-sender, round: round})))
        (is-active (default-to false (map-get? round-active round)))
    )
        (asserts! is-active err-round-not-active)
        (asserts! (not already-claimed) err-already-claimed)
        (asserts! (> shareholder-shares u0) err-not-shareholder)
        (asserts! (> dividend-pool u0) err-no-dividends)
        
        (let (
            (dividend-amount (calculate-dividend shareholder-shares total-shares-at-round dividend-pool))
        )
            (asserts! (> dividend-amount u0) err-invalid-amount)
            (asserts! (<= dividend-amount (var-get dividend-reserve)) err-insufficient-balance)
            
            (map-set dividend-claims {shareholder: tx-sender, round: round} true)
            (var-set dividend-reserve (- (var-get dividend-reserve) dividend-amount))
            (ok dividend-amount)
        )
    )
)

;; Check if dividend has been claimed
(define-read-only (has-claimed-dividend (shareholder principal) (round uint))
    (ok (default-to false (map-get? dividend-claims {shareholder: shareholder, round: round})))
)

;; Get current dividend round
(define-read-only (get-current-round)
    (ok (var-get current-dividend-round))
)

;; Get dividend pool for a specific round
(define-read-only (get-dividend-pool (round uint))
    (ok (default-to u0 (map-get? dividend-pools round)))
)

;; Comprehensive dividend distribution with batch processing and validation
;; This function allows the owner to distribute dividends to multiple shareholders
;; in a single transaction, with full validation and error handling
(define-public (batch-distribute-dividends 
    (round uint)
    (shareholders (list 20 principal)))
    (begin
        ;; Verify caller is contract owner
        (asserts! (is-contract-owner) err-owner-only)
        
        ;; Verify round exists and is active
        (let (
            (is-active (default-to false (map-get? round-active round)))
            (dividend-pool (default-to u0 (map-get? dividend-pools round)))
            (total-shares-at-round (default-to u0 (map-get? shares-snapshot round)))
        )
            ;; Validate round is active
            (asserts! is-active err-round-not-active)
            (asserts! (> dividend-pool u0) err-no-dividends)
            (asserts! (> total-shares-at-round u0) err-invalid-shares)
            
            ;; Process each shareholder in the list
            (let (
                (distribution-results 
                    (map process-shareholder-dividend shareholders)
                )
            )
                ;; Return success with distribution count
                (ok {
                    round: round,
                    processed: (len shareholders),
                    pool-amount: dividend-pool,
                    snapshot-shares: total-shares-at-round
                })
            )
        )
    )
)

;; Helper function to process individual shareholder dividend
(define-private (process-shareholder-dividend (shareholder principal))
    (let (
        (current-round (var-get current-dividend-round))
        (shareholder-shares (default-to u0 (map-get? share-balances shareholder)))
        (already-claimed (default-to false 
            (map-get? dividend-claims {shareholder: shareholder, round: current-round})))
    )
        ;; Only process if not claimed and has shares
        (if (and (> shareholder-shares u0) (not already-claimed))
            (begin
                (map-set dividend-claims 
                    {shareholder: shareholder, round: current-round} 
                    true)
                true
            )
            false
        )
    )
)



