;; ProofChain - Vendor Reputation System

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-authorized (err u201))
(define-constant err-vendor-not-found (err u202))
(define-constant err-invalid-rating (err u203))
(define-constant err-already-rated (err u204))
(define-constant err-insufficient-reputation (err u205))
(define-constant err-invalid-threshold (err u206))

;; Data Variables
(define-data-var rating-counter uint u0)
(define-data-var reputation-threshold uint u300) ;; Minimum score to avoid flagging (out of 500)
(define-data-var flagging-threshold uint u3) ;; Number of bad ratings to trigger flag

;; Data Maps
(define-map vendor-reputation
  { vendor: principal }
  {
    total-ratings: uint,
    total-score: uint,
    average-rating: uint, ;; Out of 100 (100 = 5 stars * 20)
    positive-ratings: uint, ;; Ratings >= 60 (3+ stars)
    negative-ratings: uint, ;; Ratings < 60 (< 3 stars)
    is-flagged: bool,
    flag-reason: (optional (string-ascii 128)),
    last-updated: uint,
    registration-block: uint
  }
)

(define-map customer-ratings
  { customer: principal, vendor: principal, receipt-id: uint }
  {
    rating: uint, ;; 1-100 scale (20=1 star, 40=2 stars, 60=3 stars, 80=4 stars, 100=5 stars)
    comment: (optional (string-ascii 256)),
    timestamp: uint,
    is-verified: bool ;; True if rating is from verified receipt
  }
)

(define-map vendor-flags
  { vendor: principal, flag-id: uint }
  {
    reporter: principal,
    flag-type: (string-ascii 32), ;; "poor-service", "fraud", "non-delivery", "counterfeit"
    description: (string-ascii 256),
    timestamp: uint,
    status: (string-ascii 16), ;; "pending", "reviewed", "resolved", "dismissed"
    admin-notes: (optional (string-ascii 256))
  }
)

(define-map vendor-flag-counter
  { vendor: principal }
  { counter: uint }
)

(define-map rating-history
  { rating-id: uint }
  {
    customer: principal,
    vendor: principal,
    receipt-id: (optional uint),
    rating: uint,
    timestamp: uint
  }
)

;; Private Functions
(define-private (calculate-average-rating (total-score uint) (total-ratings uint))
  (if (> total-ratings u0)
    (/ total-score total-ratings)
    u0
  )
)

(define-private (should-flag-vendor (negative-ratings uint) (total-ratings uint))
  (and (>= negative-ratings (var-get flagging-threshold))
       (> total-ratings u5) ;; At least 5 ratings before flagging
       (< (/ (* negative-ratings u100) total-ratings) u70)) ;; More than 30% negative
)

(define-private (get-next-flag-id (vendor principal))
  (default-to u0 (get counter (map-get? vendor-flag-counter { vendor: vendor })))
)

;; Public Functions

;; Initialize Vendor Reputation
(define-public (initialize-vendor-reputation (vendor principal))
  (begin
    ;; Only allow self-initialization or contract owner
    (asserts! (or (is-eq tx-sender vendor) (is-eq tx-sender contract-owner)) err-not-authorized)
    
    (ok (map-set vendor-reputation
      { vendor: vendor }
      {
        total-ratings: u0,
        total-score: u0,
        average-rating: u0,
        positive-ratings: u0,
        negative-ratings: u0,
        is-flagged: false,
        flag-reason: none,
        last-updated: stacks-block-height,
        registration-block: stacks-block-height
      }
    ))
  )
)

;; Submit Rating (with optional receipt verification)
(define-public (submit-rating 
  (vendor principal) 
  (rating uint) 
  (receipt-id (optional uint))
  (comment (optional (string-ascii 256))))
  (let ((rating-id (+ (var-get rating-counter) u1)))
    (begin
      ;; Validate rating (1-100 scale)
      (asserts! (and (>= rating u20) (<= rating u100)) err-invalid-rating)
      
      ;; Check if customer already rated this vendor for this receipt
      (match receipt-id
        some-receipt-id
          (asserts! (is-none (map-get? customer-ratings 
            { customer: tx-sender, vendor: vendor, receipt-id: some-receipt-id })) 
            err-already-rated)
        true ;; No receipt verification needed
      )

      ;; Get or initialize vendor reputation
      (let ((current-rep (default-to 
        {
          total-ratings: u0,
          total-score: u0,
          average-rating: u0,
          positive-ratings: u0,
          negative-ratings: u0,
          is-flagged: false,
          flag-reason: none,
          last-updated: stacks-block-height,
          registration-block: stacks-block-height
        }
        (map-get? vendor-reputation { vendor: vendor }))))
        
        (let ((new-total-ratings (+ (get total-ratings current-rep) u1))
              (new-total-score (+ (get total-score current-rep) rating))
              (new-positive (if (>= rating u60) 
                              (+ (get positive-ratings current-rep) u1)
                              (get positive-ratings current-rep)))
              (new-negative (if (< rating u60)
                              (+ (get negative-ratings current-rep) u1)
                              (get negative-ratings current-rep)))
              (new-average (calculate-average-rating 
                            (+ (get total-score current-rep) rating) 
                            new-total-ratings)))
          
          ;; Store individual rating
          (map-set customer-ratings
            { customer: tx-sender, vendor: vendor, receipt-id: (default-to u0 receipt-id) }
            {
              rating: rating,
              comment: comment,
              timestamp: stacks-block-height,
              is-verified: (is-some receipt-id)
            }
          )

          ;; Store in rating history
          (map-set rating-history
            { rating-id: rating-id }
            {
              customer: tx-sender,
              vendor: vendor,
              receipt-id: receipt-id,
              rating: rating,
              timestamp: stacks-block-height
            }
          )

          ;; Update vendor reputation
          (map-set vendor-reputation
            { vendor: vendor }
            (merge current-rep {
              total-ratings: new-total-ratings,
              total-score: new-total-score,
              average-rating: new-average,
              positive-ratings: new-positive,
              negative-ratings: new-negative,
              is-flagged: (or (get is-flagged current-rep) 
                             (should-flag-vendor new-negative new-total-ratings)),
              last-updated: stacks-block-height
            })
          )

          ;; Update rating counter
          (var-set rating-counter rating-id)

          (ok rating-id)
        )
      )
    )
  )
)

;; Flag Vendor for Bad Behavior
(define-public (flag-vendor 
  (vendor principal)
  (flag-type (string-ascii 32))
  (description (string-ascii 256)))
  (let ((flag-id (+ (get-next-flag-id vendor) u1)))
    (begin
      ;; Create flag record
      (map-set vendor-flags
        { vendor: vendor, flag-id: flag-id }
        {
          reporter: tx-sender,
          flag-type: flag-type,
          description: description,
          timestamp: stacks-block-height,
          status: "pending",
          admin-notes: none
        }
      )

      ;; Update flag counter
      (map-set vendor-flag-counter
        { vendor: vendor }
        { counter: flag-id }
      )

      ;; Update vendor reputation to flagged status
      (match (map-get? vendor-reputation { vendor: vendor })
        current-rep
          (map-set vendor-reputation
            { vendor: vendor }
            (merge current-rep {
              is-flagged: true,
              flag-reason: (some flag-type),
              last-updated: stacks-block-height
            })
          )
        ;; Initialize if vendor not found
        (map-set vendor-reputation
          { vendor: vendor }
          {
            total-ratings: u0,
            total-score: u0,
            average-rating: u0,
            positive-ratings: u0,
            negative-ratings: u0,
            is-flagged: true,
            flag-reason: (some flag-type),
            last-updated: stacks-block-height,
            registration-block: stacks-block-height
          }
        )
      )

      (ok flag-id)
    )
  )
)

;; Process Flag (Admin only)
(define-public (process-flag 
  (vendor principal)
  (flag-id uint)
  (new-status (string-ascii 16))
  (admin-notes (optional (string-ascii 256))))
  (match (map-get? vendor-flags { vendor: vendor, flag-id: flag-id })
    flag-data
      (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (ok (map-set vendor-flags
          { vendor: vendor, flag-id: flag-id }
          (merge flag-data {
            status: new-status,
            admin-notes: admin-notes
          })
        ))
      )
    err-vendor-not-found
  )
)

;; Unflag Vendor (Admin only)
(define-public (unflag-vendor (vendor principal))
  (match (map-get? vendor-reputation { vendor: vendor })
    current-rep
      (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (ok (map-set vendor-reputation
          { vendor: vendor }
          (merge current-rep {
            is-flagged: false,
            flag-reason: none,
            last-updated: stacks-block-height
          })
        ))
      )
    err-vendor-not-found
  )
)

;; Update Reputation Thresholds (Admin only)
(define-public (update-reputation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-threshold u500) err-invalid-threshold)
    (ok (var-set reputation-threshold new-threshold))
  )
)

(define-public (update-flagging-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= new-threshold u1) (<= new-threshold u10)) err-invalid-threshold)
    (ok (var-set flagging-threshold new-threshold))
  )
)

;; Read-only Functions

;; Get Vendor Reputation
(define-read-only (get-vendor-reputation (vendor principal))
  (map-get? vendor-reputation { vendor: vendor })
)

;; Get Customer Rating
(define-read-only (get-customer-rating (customer principal) (vendor principal) (receipt-id uint))
  (map-get? customer-ratings { customer: customer, vendor: vendor, receipt-id: receipt-id })
)

;; Get Vendor Flag
(define-read-only (get-vendor-flag (vendor principal) (flag-id uint))
  (map-get? vendor-flags { vendor: vendor, flag-id: flag-id })
)

;; Check if Vendor is Trustworthy
(define-read-only (is-vendor-trustworthy (vendor principal))
  (match (map-get? vendor-reputation { vendor: vendor })
    rep-data
      (and (not (get is-flagged rep-data))
           (>= (get average-rating rep-data) (var-get reputation-threshold))
           (>= (get total-ratings rep-data) u3)) ;; At least 3 ratings
    false
  )
)

;; Get Rating History
(define-read-only (get-rating-history (rating-id uint))
  (map-get? rating-history { rating-id: rating-id })
)

;; Get Reputation Thresholds
(define-read-only (get-reputation-threshold)
  (var-get reputation-threshold)
)

(define-read-only (get-flagging-threshold)
  (var-get flagging-threshold)
)

(define-read-only (get-rating-counter)
  (var-get rating-counter)
)

;; Calculate Reputation Score (0-500 scale)
(define-read-only (calculate-reputation-score (vendor principal))
  (match (map-get? vendor-reputation { vendor: vendor })
    rep-data
      (let ((base-score (get average-rating rep-data)) ;; 0-100
            ;; Replace min function with conditional check
            (rating-bonus (if (<= (* (get total-ratings rep-data) u5) u100)
                            (* (get total-ratings rep-data) u5)
                            u100)) ;; Up to 100 bonus
            (positive-ratio (if (> (get total-ratings rep-data) u0)
                              (/ (* (get positive-ratings rep-data) u100) (get total-ratings rep-data))
                              u0))
            (consistency-bonus (/ positive-ratio u5)) ;; Up to 20 bonus
            (penalty (if (get is-flagged rep-data) u200 u0))) ;; 200 point penalty for flags
        (if (>= (+ base-score rating-bonus consistency-bonus) penalty)
          (- (+ base-score rating-bonus consistency-bonus) penalty)
          u0)
      )
    u0
  )
)
