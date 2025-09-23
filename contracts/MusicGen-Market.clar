(define-non-fungible-token music-track uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-track-not-found (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-invalid-royalty (err u106))
(define-constant err-already-exists (err u107))
(define-constant err-invalid-price (err u108))
(define-constant err-self-transfer (err u109))

(define-data-var last-token-id uint u0)
(define-data-var platform-fee-rate uint u250)
(define-data-var platform-fee-recipient principal contract-owner)

(define-map track-data
  { token-id: uint }
  {
    creator: principal,
    prompt: (string-ascii 256),
    title: (string-ascii 64),
    genre: (string-ascii 32),
    duration: uint,
    royalty-rate: uint,
    created-at: uint,
    metadata-uri: (optional (string-ascii 256))
  }
)

(define-map market-listings
  { token-id: uint }
  {
    seller: principal,
    price: uint,
    listed-at: uint,
    active: bool
  }
)

(define-map usage-licenses
  { token-id: uint, licensee: principal }
  {
    license-type: (string-ascii 32),
    expires-at: (optional uint),
    price-paid: uint,
    granted-at: uint
  }
)

(define-map royalty-balances
  { creator: principal }
  { balance: uint }
)

(define-map total-earnings
  { token-id: uint }
  { amount: uint }
)

(define-public (mint-music-track
    (recipient principal)
    (prompt (string-ascii 256))
    (title (string-ascii 64))
    (genre (string-ascii 32))
    (duration uint)
    (royalty-rate uint)
    (metadata-uri (optional (string-ascii 256)))
  )
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (current-block stacks-block-height)
    )
    (asserts! (<= royalty-rate u1000) err-invalid-royalty)
    (asserts! (> duration u0) err-invalid-price)
    (try! (nft-mint? music-track token-id recipient))
    (map-set track-data
      { token-id: token-id }
      {
        creator: tx-sender,
        prompt: prompt,
        title: title,
        genre: genre,
        duration: duration,
        royalty-rate: royalty-rate,
        created-at: current-block,
        metadata-uri: metadata-uri
      }
    )
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

(define-public (list-for-sale (token-id uint) (price uint))
  (let
    (
      (owner (unwrap! (nft-get-owner? music-track token-id) err-track-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender owner) err-not-token-owner)
    (asserts! (> price u0) err-invalid-price)
    (map-set market-listings
      { token-id: token-id }
      {
        seller: tx-sender,
        price: price,
        listed-at: current-block,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (buy-track (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? market-listings { token-id: token-id }) err-listing-not-found))
      (track-info (unwrap! (map-get? track-data { token-id: token-id }) err-track-not-found))
      (price (get price listing))
      (seller (get seller listing))
      (creator (get creator track-info))
      (royalty-rate (get royalty-rate track-info))
      (platform-fee (/ (* price (var-get platform-fee-rate)) u10000))
      (royalty-amount (/ (* price royalty-rate) u10000))
      (seller-amount (- (- price platform-fee) royalty-amount))
    )
    (asserts! (get active listing) err-listing-not-found)
    (asserts! (not (is-eq tx-sender seller)) err-self-transfer)
    (try! (stx-transfer? price tx-sender seller))
    (if (> platform-fee u0)
      (try! (stx-transfer? platform-fee seller (var-get platform-fee-recipient)))
      true
    )
    (if (and (> royalty-amount u0) (not (is-eq creator seller)))
      (begin
        (try! (stx-transfer? royalty-amount seller creator))
        (map-set royalty-balances
          { creator: creator }
          { balance: (+ (default-to u0 (get balance (map-get? royalty-balances { creator: creator }))) royalty-amount) }
        )
      )
      true
    )
    (try! (nft-transfer? music-track token-id seller tx-sender))
    (map-set market-listings
      { token-id: token-id }
      {
        seller: seller,
        price: price,
        listed-at: (get listed-at listing),
        active: false
      }
    )
    (map-set total-earnings
      { token-id: token-id }
      { amount: (+ (default-to u0 (get amount (map-get? total-earnings { token-id: token-id }))) price) }
    )
    (ok true)
  )
)

(define-public (purchase-license
    (token-id uint)
    (license-type (string-ascii 32))
    (duration-blocks (optional uint))
  )
  (let
    (
      (track-info (unwrap! (map-get? track-data { token-id: token-id }) err-track-not-found))
      (base-price u1000000)
      (license-price (if (is-eq license-type "commercial") (* base-price u5) base-price))
      (creator (get creator track-info))
      (royalty-rate (get royalty-rate track-info))
      (royalty-amount (/ (* license-price royalty-rate) u10000))
      (platform-fee (/ (* license-price (var-get platform-fee-rate)) u10000))
      (creator-amount (- (- license-price platform-fee) royalty-amount))
      (current-block stacks-block-height)
      (expires-at (match duration-blocks
        blocks (some (+ current-block blocks))
        none
      ))
    )
    (try! (stx-transfer? license-price tx-sender creator))
    (if (> platform-fee u0)
      (try! (stx-transfer? platform-fee creator (var-get platform-fee-recipient)))
      true
    )
    (map-set usage-licenses
      { token-id: token-id, licensee: tx-sender }
      {
        license-type: license-type,
        expires-at: expires-at,
        price-paid: license-price,
        granted-at: current-block
      }
    )
    (map-set royalty-balances
      { creator: creator }
      { balance: (+ (default-to u0 (get balance (map-get? royalty-balances { creator: creator }))) creator-amount) }
    )
    (map-set total-earnings
      { token-id: token-id }
      { amount: (+ (default-to u0 (get amount (map-get? total-earnings { token-id: token-id }))) license-price) }
    )
    (ok true)
  )
)

(define-public (cancel-listing (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? market-listings { token-id: token-id }) err-listing-not-found))
      (seller (get seller listing))
    )
    (asserts! (is-eq tx-sender seller) err-not-token-owner)
    (asserts! (get active listing) err-listing-not-found)
    (map-set market-listings
      { token-id: token-id }
      {
        seller: seller,
        price: (get price listing),
        listed-at: (get listed-at listing),
        active: false
      }
    )
    (ok true)
  )
)

(define-public (set-platform-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-royalty)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (set-platform-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set platform-fee-recipient new-recipient)
    (ok true)
  )
)

(define-read-only (get-track-info (token-id uint))
  (map-get? track-data { token-id: token-id })
)

(define-read-only (get-market-listing (token-id uint))
  (map-get? market-listings { token-id: token-id })
)

(define-read-only (get-license-info (token-id uint) (licensee principal))
  (map-get? usage-licenses { token-id: token-id, licensee: licensee })
)

(define-read-only (get-royalty-balance (creator principal))
  (default-to u0 (get balance (map-get? royalty-balances { creator: creator })))
)

(define-read-only (get-total-earnings (token-id uint))
  (default-to u0 (get amount (map-get? total-earnings { token-id: token-id })))
)

(define-read-only (get-last-token-id)
  (var-get last-token-id)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-platform-fee-recipient)
  (var-get platform-fee-recipient)
)

(define-read-only (get-track-owner (token-id uint))
  (nft-get-owner? music-track token-id)
)

(define-read-only (has-valid-license (token-id uint) (licensee principal))
  (match (map-get? usage-licenses { token-id: token-id, licensee: licensee })
    license-info
    (match (get expires-at license-info)
      expiry (< stacks-block-height expiry)
      true
    )
    false
  )
)

