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
(define-constant err-invalid-rating (err u110))
(define-constant err-already-rated (err u111))
(define-constant err-collection-not-found (err u112))
(define-constant err-not-collection-owner (err u113))
(define-constant err-track-already-in-collection (err u114))
(define-constant err-track-not-in-collection (err u115))
(define-constant err-invalid-offer (err u116))
(define-constant err-offer-not-found (err u117))
(define-constant err-offer-expired (err u118))
(define-constant err-invalid-collaborator (err u119))
(define-constant err-max-collaborators (err u120))
(define-constant err-invalid-split (err u121))

(define-data-var last-token-id uint u0)
(define-data-var platform-fee-rate uint u250)
(define-data-var platform-fee-recipient principal contract-owner)
(define-data-var last-collection-id uint u0)

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

(define-map track-ratings
  { token-id: uint, reviewer: principal }
  {
    rating: uint,
    review: (string-ascii 256),
    created-at: uint
  }
)

(define-map track-rating-stats
  { token-id: uint }
  {
    total-ratings: uint,
    rating-sum: uint,
    average-rating: uint
  }
)

(define-map collections
  { collection-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    created-at: uint,
    track-count: uint
  }
)

(define-map collection-tracks
  { collection-id: uint, token-id: uint }
  { added-at: uint }
)

(define-map track-collections
  { token-id: uint }
  { collection-ids: (list 20 uint) }
)

(define-map track-offers
  { token-id: uint, bidder: principal }
  {
    price: uint,
    expires-at: uint,
    created-at: uint,
    active: bool
  }
)

(define-map track-best-offers
  { token-id: uint }
  {
    bidder: principal,
    price: uint
  }
)

(define-map track-collaborators
  { token-id: uint }
  { collaborators: (list 5 { address: principal, split: uint }) }
)

(define-map collaborator-earnings
  { collaborator: principal }
  { total-earned: uint }
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

(define-public (rate-track
    (token-id uint)
    (rating uint)
    (review (string-ascii 256))
  )
  (let
    (
      (track-exists (is-some (map-get? track-data { token-id: token-id })))
      (existing-rating (map-get? track-ratings { token-id: token-id, reviewer: tx-sender }))
      (current-stats (default-to { total-ratings: u0, rating-sum: u0, average-rating: u0 }
                     (map-get? track-rating-stats { token-id: token-id })))
      (current-block stacks-block-height)
    )
    (asserts! track-exists err-track-not-found)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (is-none existing-rating) err-already-rated)
    (map-set track-ratings
      { token-id: token-id, reviewer: tx-sender }
      {
        rating: rating,
        review: review,
        created-at: current-block
      }
    )
    (let
      (
        (new-total (+ (get total-ratings current-stats) u1))
        (new-sum (+ (get rating-sum current-stats) rating))
        (new-average (/ new-sum new-total))
      )
      (map-set track-rating-stats
        { token-id: token-id }
        {
          total-ratings: new-total,
          rating-sum: new-sum,
          average-rating: new-average
        }
      )
    )
    (ok true)
  )
)

(define-public (create-collection
    (name (string-ascii 64))
    (description (string-ascii 256))
  )
  (let
    (
      (collection-id (+ (var-get last-collection-id) u1))
      (current-block stacks-block-height)
    )
    (map-set collections
      { collection-id: collection-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        created-at: current-block,
        track-count: u0
      }
    )
    (var-set last-collection-id collection-id)
    (ok collection-id)
  )
)

(define-public (add-track-to-collection (collection-id uint) (token-id uint))
  (let
    (
      (collection (unwrap! (map-get? collections { collection-id: collection-id }) err-collection-not-found))
      (track-exists (is-some (map-get? track-data { token-id: token-id })))
      (already-in-collection (is-some (map-get? collection-tracks { collection-id: collection-id, token-id: token-id })))
      (current-collections (default-to (list) (get collection-ids (map-get? track-collections { token-id: token-id }))))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get owner collection)) err-not-collection-owner)
    (asserts! track-exists err-track-not-found)
    (asserts! (not already-in-collection) err-track-already-in-collection)
    (map-set collection-tracks
      { collection-id: collection-id, token-id: token-id }
      { added-at: current-block }
    )
    (map-set track-collections
      { token-id: token-id }
      { collection-ids: (unwrap! (as-max-len? (append current-collections collection-id) u20) err-already-exists) }
    )
    (map-set collections
      { collection-id: collection-id }
      {
        owner: (get owner collection),
        name: (get name collection),
        description: (get description collection),
        created-at: (get created-at collection),
        track-count: (+ (get track-count collection) u1)
      }
    )
    (ok true)
  )
)

(define-public (remove-track-from-collection (collection-id uint) (token-id uint))
  (let
    (
      (collection (unwrap! (map-get? collections { collection-id: collection-id }) err-collection-not-found))
      (track-in-collection (is-some (map-get? collection-tracks { collection-id: collection-id, token-id: token-id })))
      (current-collections (default-to (list) (get collection-ids (map-get? track-collections { token-id: token-id }))))
    )
    (asserts! (is-eq tx-sender (get owner collection)) err-not-collection-owner)
    (asserts! track-in-collection err-track-not-in-collection)
    (map-delete collection-tracks { collection-id: collection-id, token-id: token-id })
    (map-set track-collections
      { token-id: token-id }
      { collection-ids: (filter is-not-collection-id current-collections) }
    )
    (map-set collections
      { collection-id: collection-id }
      {
        owner: (get owner collection),
        name: (get name collection),
        description: (get description collection),
        created-at: (get created-at collection),
        track-count: (- (get track-count collection) u1)
      }
    )
    (ok true)
  )
)

(define-private (is-not-collection-id (id uint))
  (not (is-eq id (var-get last-collection-id)))
)

(define-public (make-offer
    (token-id uint)
    (price uint)
    (duration-blocks uint)
  )
  (let
    (
      (track-exists (is-some (map-get? track-data { token-id: token-id })))
      (owner (unwrap! (nft-get-owner? music-track token-id) err-track-not-found))
      (current-block stacks-block-height)
      (expires-at (+ current-block duration-blocks))
      (existing-offer (map-get? track-offers { token-id: token-id, bidder: tx-sender }))
      (best-offer (map-get? track-best-offers { token-id: token-id }))
    )
    (asserts! track-exists err-track-not-found)
    (asserts! (> price u0) err-invalid-price)
    (asserts! (> duration-blocks u0) err-invalid-offer)
    (asserts! (not (is-eq tx-sender owner)) err-self-transfer)
    (map-set track-offers
      { token-id: token-id, bidder: tx-sender }
      {
        price: price,
        expires-at: expires-at,
        created-at: current-block,
        active: true
      }
    )
    (match best-offer
      current-best
      (if (> price (get price current-best))
        (map-set track-best-offers
          { token-id: token-id }
          { bidder: tx-sender, price: price }
        )
        true
      )
      (map-set track-best-offers
        { token-id: token-id }
        { bidder: tx-sender, price: price }
      )
    )
    (ok true)
  )
)

(define-public (accept-offer (token-id uint) (bidder principal))
  (let
    (
      (owner (unwrap! (nft-get-owner? music-track token-id) err-track-not-found))
      (track-info (unwrap! (map-get? track-data { token-id: token-id }) err-track-not-found))
      (offer (unwrap! (map-get? track-offers { token-id: token-id, bidder: bidder }) err-offer-not-found))
      (price (get price offer))
      (creator (get creator track-info))
      (royalty-rate (get royalty-rate track-info))
      (platform-fee (/ (* price (var-get platform-fee-rate)) u10000))
      (royalty-amount (/ (* price royalty-rate) u10000))
      (seller-amount (- (- price platform-fee) royalty-amount))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender owner) err-not-token-owner)
    (asserts! (get active offer) err-offer-not-found)
    (asserts! (< current-block (get expires-at offer)) err-offer-expired)
    (try! (stx-transfer? price bidder tx-sender))
    (if (> platform-fee u0)
      (try! (stx-transfer? platform-fee tx-sender (var-get platform-fee-recipient)))
      true
    )
    (if (and (> royalty-amount u0) (not (is-eq creator tx-sender)))
      (begin
        (try! (stx-transfer? royalty-amount tx-sender creator))
        (map-set royalty-balances
          { creator: creator }
          { balance: (+ (default-to u0 (get balance (map-get? royalty-balances { creator: creator }))) royalty-amount) }
        )
      )
      true
    )
    (try! (nft-transfer? music-track token-id tx-sender bidder))
    (map-set track-offers
      { token-id: token-id, bidder: bidder }
      {
        price: price,
        expires-at: (get expires-at offer),
        created-at: (get created-at offer),
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

(define-public (cancel-offer (token-id uint))
  (let
    (
      (offer (unwrap! (map-get? track-offers { token-id: token-id, bidder: tx-sender }) err-offer-not-found))
    )
    (asserts! (get active offer) err-offer-not-found)
    (map-set track-offers
      { token-id: token-id, bidder: tx-sender }
      {
        price: (get price offer),
        expires-at: (get expires-at offer),
        created-at: (get created-at offer),
        active: false
      }
    )
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

(define-read-only (get-track-rating (token-id uint) (reviewer principal))
  (map-get? track-ratings { token-id: token-id, reviewer: reviewer })
)

(define-read-only (get-track-rating-stats (token-id uint))
  (map-get? track-rating-stats { token-id: token-id })
)

(define-read-only (get-track-average-rating (token-id uint))
  (default-to u0 (get average-rating (map-get? track-rating-stats { token-id: token-id })))
)

(define-read-only (get-track-total-ratings (token-id uint))
  (default-to u0 (get total-ratings (map-get? track-rating-stats { token-id: token-id })))
)

(define-read-only (get-collection-info (collection-id uint))
  (map-get? collections { collection-id: collection-id })
)

(define-read-only (get-track-collections (token-id uint))
  (map-get? track-collections { token-id: token-id })
)

(define-read-only (is-track-in-collection (collection-id uint) (token-id uint))
  (is-some (map-get? collection-tracks { collection-id: collection-id, token-id: token-id }))
)

(define-read-only (get-last-collection-id)
  (var-get last-collection-id)
)

(define-read-only (get-offer (token-id uint) (bidder principal))
  (map-get? track-offers { token-id: token-id, bidder: bidder })
)

(define-read-only (get-best-offer (token-id uint))
  (map-get? track-best-offers { token-id: token-id })
)

(define-read-only (is-offer-valid (token-id uint) (bidder principal))
  (match (map-get? track-offers { token-id: token-id, bidder: bidder })
    offer
    (and (get active offer) (< stacks-block-height (get expires-at offer)))
    false
  )
)

(define-private (validate-split-total (collaborators (list 5 { address: principal, split: uint })))
  (fold + (map get-split collaborators) u0)
)

(define-private (get-split (entry { address: principal, split: uint }))
  (get split entry)
)

(define-public (set-track-collaborators
    (token-id uint)
    (collaborators (list 5 { address: principal, split: uint }))
  )
  (let
    (
      (track-info (unwrap! (map-get? track-data { token-id: token-id }) err-track-not-found))
      (creator (get creator track-info))
      (total-split (validate-split-total collaborators))
    )
    (asserts! (is-eq tx-sender creator) err-not-token-owner)
    (asserts! (<= (len collaborators) u5) err-max-collaborators)
    (asserts! (<= total-split u10000) err-invalid-split)
    (map-set track-collaborators
      { token-id: token-id }
      { collaborators: collaborators }
    )
    (ok true)
  )
)

(define-private (distribute-to-collaborator (entry { address: principal, split: uint }) (state { amount: uint, remaining: uint }))
  (let
    (
      (share (/ (* (get amount state) (get split entry)) u10000))
      (collaborator-addr (get address entry))
      (current-earnings (default-to u0 (get total-earned (map-get? collaborator-earnings { collaborator: collaborator-addr }))))
    )
    (map-set collaborator-earnings
      { collaborator: collaborator-addr }
      { total-earned: (+ current-earnings share) }
    )
    { amount: (get amount state), remaining: (- (get remaining state) share) }
  )
)

(define-public (distribute-collaboration-royalties (token-id uint) (amount uint))
  (let
    (
      (track-info (unwrap! (map-get? track-data { token-id: token-id }) err-track-not-found))
      (creator (get creator track-info))
      (collab-data (map-get? track-collaborators { token-id: token-id }))
    )
    (asserts! (is-eq tx-sender creator) err-not-token-owner)
    (match collab-data
      collabs
      (let
        (
          (result (fold distribute-to-collaborator (get collaborators collabs) { amount: amount, remaining: amount }))
          (creator-share (get remaining result))
          (current-creator-earnings (default-to u0 (get total-earned (map-get? collaborator-earnings { collaborator: creator }))))
        )
        (map-set collaborator-earnings
          { collaborator: creator }
          { total-earned: (+ current-creator-earnings creator-share) }
        )
        (ok creator-share)
      )
      (ok amount)
    )
  )
)

(define-read-only (get-track-collaborators (token-id uint))
  (map-get? track-collaborators { token-id: token-id })
)

(define-read-only (get-collaborator-earnings (collaborator principal))
  (default-to u0 (get total-earned (map-get? collaborator-earnings { collaborator: collaborator })))
)
