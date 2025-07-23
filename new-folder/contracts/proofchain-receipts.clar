;; ProofChain - Digital Receipts + Warranty Smart Contract
;; Version: 1.0.0
;; Compatible with Clarinet 2.0+

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-receipt-not-found (err u102))
(define-constant err-warranty-expired (err u103))
(define-constant err-invalid-merchant (err u104))
(define-constant err-invalid-warranty-period (err u105))
(define-constant err-claim-already-processed (err u106))
(define-constant err-insufficient-funds (err u107))

;; Data Variables
(define-data-var receipt-counter uint u0)
(define-data-var platform-fee uint u50) ;; 0.5% fee in basis points

;; Data Maps
(define-map receipts
  { receipt-id: uint }
  {
    owner: principal,
    merchant: principal,
    product-id: (string-ascii 64),
    product-name: (string-ascii 128),
    purchase-price: uint,
    purchase-timestamp: uint,
    warranty-period-days: uint,
    warranty-type: (string-ascii 32), ;; "manufacturer", "retailer", "extended"
    metadata-uri: (optional (string-ascii 256)),
    is-active: bool
  }
)
(define-map warranty-claims
  { receipt-id: uint, claim-id: uint }
  {
    claimant: principal,
    claim-type: (string-ascii 32), ;; "refund", "repair", "replacement"
    claim-timestamp: uint,
    claim-amount: uint,
    status: (string-ascii 16), ;; "pending", "approved", "rejected", "completed"
    processor: (optional principal)
  }
)
(define-map authorized-merchants
  { merchant: principal }
  {
    name: (string-ascii 64),
    is-active: bool,
    registration-timestamp: uint
  }
)
(define-map receipt-claim-counter
  { receipt-id: uint }
  { counter: uint }
)

;; Private Functions
(define-private (is-warranty-valid (receipt-id uint))
  (match (map-get? receipts { receipt-id: receipt-id })
    receipt-data
      (let ((warranty-expiry (+ (get purchase-timestamp receipt-data)
                                (* (get warranty-period-days receipt-data) u86400))))
        (< stacks-block-height warranty-expiry))
    false
  )
)
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee)) u10000)
)
(define-private (get-next-claim-id (receipt-id uint))
  (default-to u0 (get counter (map-get? receipt-claim-counter { receipt-id: receipt-id })))
)

;; Public Functions

;; Merchant Registration
(define-public (register-merchant (merchant principal) (name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-merchants
      { merchant: merchant }
      {
        name: name,
        is-active: true,
        registration-timestamp: stacks-block-height
      }
    ))
  )
)

;; Deactivate Merchant
(define-public (deactivate-merchant (merchant principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? authorized-merchants { merchant: merchant })
      merchant-data
        (ok (map-set authorized-merchants
          { merchant: merchant }
          (merge merchant-data { is-active: false })
        ))
      err-invalid-merchant
    )
  )
)

;; Issue Digital Receipt (NFT)
(define-public (issue-receipt
  (customer principal)
  (product-id (string-ascii 64))
  (product-name (string-ascii 128))
  (purchase-price uint)
  (warranty-period-days uint)
  (warranty-type (string-ascii 32))
  (metadata-uri (optional (string-ascii 256))))
  (let ((receipt-id (+ (var-get receipt-counter) u1)))
    (begin
      ;; Verify merchant is authorized and active
      (let
        ((merchant-data (unwrap! (map-get? authorized-merchants { merchant: tx-sender }) err-invalid-merchant)))
        (asserts! (get is-active merchant-data) err-invalid-merchant)
      )

      ;; Validate warranty period (max 10 years)
      (asserts! (<= warranty-period-days u3650) err-invalid-warranty-period)

      ;; Create receipt NFT
      (map-set receipts
        { receipt-id: receipt-id }
        {
          owner: customer,
          merchant: tx-sender,
          product-id: product-id,
          product-name: product-name,
          purchase-price: purchase-price,
          purchase-timestamp: stacks-block-height, ;; Changed to stacks-block-height
          warranty-period-days: warranty-period-days,
          warranty-type: warranty-type,
          metadata-uri: metadata-uri,
          is-active: true
        }
      )

      ;; Initialize claim counter for this receipt
      (map-set receipt-claim-counter
        { receipt-id: receipt-id }
        { counter: u0 }
      )

      ;; Update receipt counter
      (var-set receipt-counter receipt-id)

      (ok receipt-id)
    )
  )
)

;; Transfer Receipt Ownership
(define-public (transfer-receipt (receipt-id uint) (new-owner principal))
  (match (map-get? receipts { receipt-id: receipt-id })
    receipt-data
      (begin
        (asserts! (is-eq tx-sender (get owner receipt-data)) err-not-authorized)
        (asserts! (get is-active receipt-data) err-receipt-not-found)
        (ok (map-set receipts
          { receipt-id: receipt-id }
          (merge receipt-data { owner: new-owner })
        ))
      )
    err-receipt-not-found
  )
)

;; Submit Warranty Claim
(define-public (submit-warranty-claim
  (receipt-id uint)
  (claim-type (string-ascii 32))
  (claim-amount uint))
  (match (map-get? receipts { receipt-id: receipt-id })
    receipt-data
      (let ((claim-id (+ (get-next-claim-id receipt-id) u1)))
        (begin
          ;; Verify ownership
          (asserts! (is-eq tx-sender (get owner receipt-data)) err-not-authorized)

          ;; Verify receipt is active
          (asserts! (get is-active receipt-data) err-receipt-not-found)

          ;; Verify warranty is still valid
          (asserts! (is-warranty-valid receipt-id) err-warranty-expired)

          ;; Verify claim amount doesn't exceed purchase price
          (asserts! (<= claim-amount (get purchase-price receipt-data)) err-insufficient-funds)

          ;; Create warranty claim
          (map-set warranty-claims
            { receipt-id: receipt-id, claim-id: claim-id }
            {
              claimant: tx-sender,
              claim-type: claim-type,
              claim-timestamp: stacks-block-height, ;; Changed to stacks-block-height
              claim-amount: claim-amount,
              status: "pending",
              processor: none
            }
          )

          ;; Update claim counter
          (map-set receipt-claim-counter
            { receipt-id: receipt-id }
            { counter: claim-id }
          )

          (ok { receipt-id: receipt-id, claim-id: claim-id })
        )
      )
    err-receipt-not-found
  )
)

;; Process Warranty Claim (Merchant/Owner only)
(define-public (process-warranty-claim
  (receipt-id uint)
  (claim-id uint)
  (new-status (string-ascii 16)))
  (match (map-get? receipts { receipt-id: receipt-id })
    receipt-data
      (match (map-get? warranty-claims { receipt-id: receipt-id, claim-id: claim-id })
        claim-data
          (begin
            ;; Verify processor authority (merchant or contract owner)
            (asserts! (or (is-eq tx-sender (get merchant receipt-data))
                          (is-eq tx-sender contract-owner)) err-not-authorized)

            ;; Verify claim is still pending
            (asserts! (is-eq (get status claim-data) "pending") err-claim-already-processed)

            ;; Update claim status
            (ok (map-set warranty-claims
              { receipt-id: receipt-id, claim-id: claim-id }
              (merge claim-data {
                status: new-status,
                processor: (some tx-sender)
              })
            ))
          )
        err-receipt-not-found
      )
    err-receipt-not-found
  )
)

;; Deactivate Receipt
(define-public (deactivate-receipt (receipt-id uint))
  (match (map-get? receipts { receipt-id: receipt-id })
    receipt-data
      (begin
        ;; Only owner or merchant can deactivate
        (asserts! (or (is-eq tx-sender (get owner receipt-data))
                      (is-eq tx-sender (get merchant receipt-data))
                      (is-eq tx-sender contract-owner)) err-not-authorized)

        (ok (map-set receipts
          { receipt-id: receipt-id }
          (merge receipt-data { is-active: false })
        ))
      )
    err-receipt-not-found
  )
)

;; Update Platform Fee (Owner only)
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-warranty-period) ;; Max 10%
    (ok (var-set platform-fee new-fee))
  )
)

;; Read-only Functions
;; Get Receipt Details
(define-read-only (get-receipt (receipt-id uint))
  (map-get? receipts { receipt-id: receipt-id })
)

;; Check Warranty Status
(define-read-only (check-warranty-status (receipt-id uint))
  (match (map-get? receipts { receipt-id: receipt-id })
    receipt-data
      (let ((warranty-expiry (+ (get purchase-timestamp receipt-data)
                                (* (get warranty-period-days receipt-data) u86400)))
            (days-remaining (if (> warranty-expiry stacks-block-height) ;; Changed to stacks-block-height
                                (/ (- warranty-expiry stacks-block-height) u86400) ;; Changed to stacks-block-height
                                u0)))
        (ok {
          is-valid: (< stacks-block-height warranty-expiry), ;; Changed to stacks-block-height
          expiry-block: warranty-expiry,
          days-remaining: days-remaining,
          warranty-type: (get warranty-type receipt-data)
        })
      )
    err-receipt-not-found
  )
)

;; Get Warranty Claim
(define-read-only (get-warranty-claim (receipt-id uint) (claim-id uint))
  (map-get? warranty-claims { receipt-id: receipt-id, claim-id: claim-id })
)

;; Get Merchant Info
(define-read-only (get-merchant-info (merchant principal))
  (map-get? authorized-merchants { merchant: merchant })
)

;; Get Receipt Counter
(define-read-only (get-receipt-counter)
  (var-get receipt-counter)
)

;; Get Platform Fee
(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

;; Check if user owns receipt
(define-read-only (is-receipt-owner (receipt-id uint) (user principal))
  (match (map-get? receipts { receipt-id: receipt-id })
    receipt-data (is-eq user (get owner receipt-data))
    false
  )
)
