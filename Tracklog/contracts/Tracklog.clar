;; Define the Masterpiece NFT
(define-non-fungible-token masterpiece-id uint)

;; Define the exhibitions map
(define-map gallery-exhibitions
  {masterpiece-id: uint}
  {artist: principal, exhibition-price: uint, exhibited-at: uint})

;; Define the artist commissions map
(define-map artist-commissions
  {masterpiece-id: uint}
  {original-artist: principal, commission-rate: uint})

;; Define the gallery curator
(define-data-var gallery-curator principal tx-sender)

;; Define gallery state (for maintenance functionality)
(define-data-var gallery-closed bool false)

;; Define constants
(define-constant ARTWORK_MIN_PRICE u1)
(define-constant ARTWORK_MAX_PRICE u1000000000) ;; 1 billion microSTX
(define-constant MAX_COMMISSION_RATE u25) ;; 25%
(define-constant EXHIBITION_UPDATE_DELAY u86400) ;; 24 hours in seconds
(define-constant GALLERY_OWNER tx-sender)
(define-constant MAX_MASTERPIECE_ID u1000000) ;; Maximum allowed masterpiece ID

;; Error codes
(define-constant ERR_NOT_EXHIBITED (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_ACQUISITION_FAILED (err u103))
(define-constant ERR_INVALID_COMMISSION (err u104))
(define-constant ERR_ACCESS_DENIED (err u105))
(define-constant ERR_SELF_ACQUISITION (err u106))
(define-constant ERR_INVALID_EXHIBITION_PRICE (err u107))
(define-constant ERR_EXHIBITION_DELAY_ACTIVE (err u108))
(define-constant ERR_GALLERY_MAINTENANCE (err u109))
(define-constant ERR_ALREADY_EXHIBITED (err u110))
(define-constant ERR_INVALID_MASTERPIECE_ID (err u111))
(define-constant ERR_INVALID_CURATOR (err u112))

;; Helper function to validate masterpiece ID
(define-private (validate-masterpiece-id (piece-id uint))
  (and 
    (>= piece-id u0)
    (<= piece-id MAX_MASTERPIECE_ID)))

;; Helper function to validate curator
(define-private (validate-curator (new-curator principal))
  (and 
    (not (is-eq new-curator GALLERY_OWNER))
    (not (is-eq new-curator (var-get gallery-curator)))))

;; Administrative Functions

(define-public (set-gallery-curator (new-curator principal))
  (begin
    (asserts! (is-eq tx-sender GALLERY_OWNER) ERR_ACCESS_DENIED)
    (asserts! (validate-curator new-curator) ERR_INVALID_CURATOR)
    (var-set gallery-curator new-curator)
    (print {event: "curator-appointed", new-curator: new-curator})
    (ok true)))

(define-public (toggle-gallery-maintenance)
  (begin
    (asserts! (is-eq tx-sender (var-get gallery-curator)) ERR_ACCESS_DENIED)
    (ok (var-set gallery-closed (not (var-get gallery-closed))))))

;; Helper Functions

(define-read-only (is-artwork-exhibited (piece-id uint))
  (is-some (map-get? gallery-exhibitions {masterpiece-id: piece-id})))

(define-read-only (get-exhibition-details (piece-id uint))
  (map-get? gallery-exhibitions {masterpiece-id: piece-id}))

(define-read-only (calculate-artist-commission (price uint) (rate uint))
  (/ (* price rate) u100))

(define-read-only (get-artist-commission-info (piece-id uint))
  (default-to {original-artist: tx-sender, commission-rate: u0}
    (map-get? artist-commissions {masterpiece-id: piece-id})))

;; Core Functions

(define-public (create-masterpiece (piece-id uint) (commission-rate uint))
  (begin
    (asserts! (not (var-get gallery-closed)) ERR_GALLERY_MAINTENANCE)
    (asserts! (validate-masterpiece-id piece-id) ERR_INVALID_MASTERPIECE_ID)
    (asserts! (is-none (nft-get-owner? masterpiece-id piece-id)) (err u300))
    (asserts! (<= commission-rate MAX_COMMISSION_RATE) ERR_INVALID_COMMISSION)
    (try! (nft-mint? masterpiece-id piece-id tx-sender))
    (map-set artist-commissions
      {masterpiece-id: piece-id}
      {original-artist: tx-sender, commission-rate: commission-rate})
    (print {event: "masterpiece-created", piece-id: piece-id, artist: tx-sender})
    (ok true)))

(define-public (exhibit-artwork (piece-id uint) (exhibition-price uint))
  (let ((owner (nft-get-owner? masterpiece-id piece-id)))
    (begin
      (asserts! (not (var-get gallery-closed)) ERR_GALLERY_MAINTENANCE)
      (asserts! (validate-masterpiece-id piece-id) ERR_INVALID_MASTERPIECE_ID)
      (asserts! (is-some owner) (err u305))
      (asserts! (is-eq (some tx-sender) owner) (err u301))
      (asserts! (and (>= exhibition-price ARTWORK_MIN_PRICE) (<= exhibition-price ARTWORK_MAX_PRICE)) ERR_INVALID_EXHIBITION_PRICE)
      (asserts! (not (is-artwork-exhibited piece-id)) ERR_ALREADY_EXHIBITED)
      (map-set gallery-exhibitions
        {masterpiece-id: piece-id}
        {artist: tx-sender, exhibition-price: exhibition-price, exhibited-at: stacks-block-height})
      (print {event: "artwork-exhibited", piece-id: piece-id, price: exhibition-price, artist: tx-sender})
      (ok true))))

(define-public (update-exhibition-price (piece-id uint) (new-price uint))
  (let (
    (exhibition (unwrap! (map-get? gallery-exhibitions {masterpiece-id: piece-id}) ERR_NOT_EXHIBITED))
    (current-height stacks-block-height)
  )
    (begin
      (asserts! (not (var-get gallery-closed)) ERR_GALLERY_MAINTENANCE)
      (asserts! (validate-masterpiece-id piece-id) ERR_INVALID_MASTERPIECE_ID)
      (asserts! (is-eq tx-sender (get artist exhibition)) ERR_ACCESS_DENIED)
      (asserts! (and (>= new-price ARTWORK_MIN_PRICE) (<= new-price ARTWORK_MAX_PRICE)) ERR_INVALID_EXHIBITION_PRICE)
      (asserts! (>= (- current-height (get exhibited-at exhibition)) EXHIBITION_UPDATE_DELAY) ERR_EXHIBITION_DELAY_ACTIVE)
      (map-set gallery-exhibitions
        {masterpiece-id: piece-id}
        {artist: tx-sender, exhibition-price: new-price, exhibited-at: current-height})
      (print {event: "exhibition-price-updated", piece-id: piece-id, new-price: new-price})
      (ok true))))

(define-public (remove-from-exhibition (piece-id uint))
  (let ((exhibition (unwrap! (map-get? gallery-exhibitions {masterpiece-id: piece-id}) ERR_NOT_EXHIBITED)))
    (begin
      (asserts! (not (var-get gallery-closed)) ERR_GALLERY_MAINTENANCE)
      (asserts! (validate-masterpiece-id piece-id) ERR_INVALID_MASTERPIECE_ID)
      (asserts! (is-eq tx-sender (get artist exhibition)) ERR_ACCESS_DENIED)
      (map-delete gallery-exhibitions {masterpiece-id: piece-id})
      (print {event: "artwork-removed-from-exhibition", piece-id: piece-id})
      (ok true))))

(define-public (acquire-masterpiece (piece-id uint))
  (let (
    (exhibition (unwrap! (map-get? gallery-exhibitions {masterpiece-id: piece-id}) ERR_NOT_EXHIBITED))
    (commission-info (default-to {original-artist: tx-sender, commission-rate: u0} 
      (map-get? artist-commissions {masterpiece-id: piece-id})))
    (collector tx-sender)
    (current-owner (get artist exhibition))
  )
    (begin
      (asserts! (not (var-get gallery-closed)) ERR_GALLERY_MAINTENANCE)
      (asserts! (validate-masterpiece-id piece-id) ERR_INVALID_MASTERPIECE_ID)
      (asserts! (not (is-eq collector current-owner)) ERR_SELF_ACQUISITION)
      (asserts! (is-some (nft-get-owner? masterpiece-id piece-id)) (err u309))
      (let (
        (price (get exhibition-price exhibition))
        (commission-amount (calculate-artist-commission price (get commission-rate commission-info)))
        (owner-amount (- price commission-amount))
      )
        (asserts! (>= (stx-get-balance collector) price) ERR_INSUFFICIENT_BALANCE)
        ;; Transfer commission to original artist if applicable
        (if (> commission-amount u0)
          (try! (stx-transfer? commission-amount collector (get original-artist commission-info)))
          true)
        ;; Transfer remaining amount to current owner
        (try! (stx-transfer? owner-amount collector current-owner))
        ;; Transfer NFT to collector
        (match (nft-transfer? masterpiece-id piece-id current-owner collector)
          success (begin
            (map-delete gallery-exhibitions {masterpiece-id: piece-id})
            (print {
              event: "masterpiece-acquired",
              piece-id: piece-id,
              collector: collector,
              previous-owner: current-owner,
              price: price,
              commission: commission-amount
            })
            (ok true))
          error (begin
            (try! (stx-transfer? price current-owner collector))
            ERR_ACQUISITION_FAILED))))))

(define-public (gift-masterpiece (piece-id uint) (recipient principal))
  (let ((owner (nft-get-owner? masterpiece-id piece-id)))
    (begin
      (asserts! (not (var-get gallery-closed)) ERR_GALLERY_MAINTENANCE)
      (asserts! (validate-masterpiece-id piece-id) ERR_INVALID_MASTERPIECE_ID)
      (asserts! (is-some owner) (err u306))
      (asserts! (is-eq (some tx-sender) owner) (err u304))
      (asserts! (not (is-eq recipient tx-sender)) ERR_SELF_ACQUISITION)
      (try! (nft-transfer? masterpiece-id piece-id tx-sender recipient))
      (print {event: "masterpiece-gifted", piece-id: piece-id, from: tx-sender, to: recipient})
      (ok true))))