;; Storage Coordination Contract
;; Optimizes battery usage and energy storage

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_STORAGE_NOT_FOUND (err u301))
(define-constant ERR_INSUFFICIENT_CAPACITY (err u302))
(define-constant ERR_INVALID_OPERATION (err u303))

;; Storage types
(define-constant LITHIUM_ION u1)
(define-constant FLOW_BATTERY u2)
(define-constant COMPRESSED_AIR u3)
(define-constant PUMPED_HYDRO u4)

;; Storage systems
(define-map storage-systems
  { storage-id: uint }
  {
    owner: principal,
    storage-type: uint,
    total-capacity: uint,
    current-charge: uint,
    max-charge-rate: uint,
    max-discharge-rate: uint,
    efficiency: uint,
    location: (string-ascii 100)
  }
)

(define-map storage-operations
  { operation-id: uint }
  {
    storage-id: uint,
    operation-type: bool, ;; true for charge, false for discharge
    amount: uint,
    timestamp: uint,
    grid-node: (string-ascii 50)
  }
)

(define-data-var next-storage-id uint u1)
(define-data-var next-operation-id uint u1)

;; Register storage system
(define-public (register-storage (storage-type uint) (total-capacity uint) (max-charge-rate uint) (max-discharge-rate uint) (location (string-ascii 100)))
  (let ((storage-id (var-get next-storage-id)))
    (asserts! (> total-capacity u0) ERR_INSUFFICIENT_CAPACITY)
    (asserts! (> max-charge-rate u0) ERR_INVALID_OPERATION)
    (asserts! (> max-discharge-rate u0) ERR_INVALID_OPERATION)

    (map-set storage-systems
      { storage-id: storage-id }
      {
        owner: tx-sender,
        storage-type: storage-type,
        total-capacity: total-capacity,
        current-charge: u0,
        max-charge-rate: max-charge-rate,
        max-discharge-rate: max-discharge-rate,
        efficiency: u90, ;; 90% default efficiency
        location: location
      }
    )

    (var-set next-storage-id (+ storage-id u1))
    (ok storage-id)
  )
)

;; Charge storage system
(define-public (charge-storage (storage-id uint) (amount uint) (grid-node (string-ascii 50)))
  (match (map-get? storage-systems { storage-id: storage-id })
    storage-data
    (let ((new-charge (+ (get current-charge storage-data) amount))
          (operation-id (var-get next-operation-id)))
      (asserts! (is-eq (get owner storage-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (<= amount (get max-charge-rate storage-data)) ERR_INVALID_OPERATION)
      (asserts! (<= new-charge (get total-capacity storage-data)) ERR_INSUFFICIENT_CAPACITY)

      (map-set storage-systems
        { storage-id: storage-id }
        (merge storage-data { current-charge: new-charge })
      )

      (map-set storage-operations
        { operation-id: operation-id }
        {
          storage-id: storage-id,
          operation-type: true,
          amount: amount,
          timestamp: block-height,
          grid-node: grid-node
        }
      )

      (var-set next-operation-id (+ operation-id u1))
      (ok operation-id)
    )
    ERR_STORAGE_NOT_FOUND
  )
)

;; Discharge storage system
(define-public (discharge-storage (storage-id uint) (amount uint) (grid-node (string-ascii 50)))
  (match (map-get? storage-systems { storage-id: storage-id })
    storage-data
    (let ((new-charge (- (get current-charge storage-data) amount))
          (operation-id (var-get next-operation-id)))
      (asserts! (is-eq (get owner storage-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (<= amount (get max-discharge-rate storage-data)) ERR_INVALID_OPERATION)
      (asserts! (>= (get current-charge storage-data) amount) ERR_INSUFFICIENT_CAPACITY)

      (map-set storage-systems
        { storage-id: storage-id }
        (merge storage-data { current-charge: new-charge })
      )

      (map-set storage-operations
        { operation-id: operation-id }
        {
          storage-id: storage-id,
          operation-type: false,
          amount: amount,
          timestamp: block-height,
          grid-node: grid-node
        }
      )

      (var-set next-operation-id (+ operation-id u1))
      (ok operation-id)
    )
    ERR_STORAGE_NOT_FOUND
  )
)

;; Optimize storage allocation
(define-public (optimize-storage-allocation (storage-id uint) (target-charge uint))
  (match (map-get? storage-systems { storage-id: storage-id })
    storage-data
    (begin
      (asserts! (is-eq (get owner storage-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (<= target-charge (get total-capacity storage-data)) ERR_INSUFFICIENT_CAPACITY)

      ;; Simple optimization: move towards target charge
      (let ((current-charge (get current-charge storage-data))
            (charge-diff (if (> target-charge current-charge)
                           (- target-charge current-charge)
                           (- current-charge target-charge))))
        (ok {
          recommended-action: (> target-charge current-charge),
          amount: charge-diff,
          efficiency-gain: (/ (* charge-diff u100) (get total-capacity storage-data))
        })
      )
    )
    ERR_STORAGE_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-storage-system (storage-id uint))
  (map-get? storage-systems { storage-id: storage-id })
)

(define-read-only (get-storage-operation (operation-id uint))
  (map-get? storage-operations { operation-id: operation-id })
)

(define-read-only (get-storage-efficiency (storage-id uint))
  (match (map-get? storage-systems { storage-id: storage-id })
    storage-data (get efficiency storage-data)
    u0
  )
)

(define-read-only (calculate-storage-utilization (storage-id uint))
  (match (map-get? storage-systems { storage-id: storage-id })
    storage-data
    (/ (* (get current-charge storage-data) u100) (get total-capacity storage-data))
    u0
  )
)
