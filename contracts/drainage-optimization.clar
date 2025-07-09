;; Drainage Optimization Contract
;; Manages water flow through urban infrastructure

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_DRAIN_EXISTS (err u201))
(define-constant ERR_DRAIN_NOT_FOUND (err u202))
(define-constant ERR_INVALID_DATA (err u203))
(define-constant ERR_INSUFFICIENT_BALANCE (err u204))

;; Data Variables
(define-data-var total-drains uint u0)
(define-data-var total-optimizations uint u0)
(define-data-var optimization-reward uint u15)
(define-data-var efficiency-threshold uint u80)

;; Define fungible token for rewards
(define-fungible-token drainage-token)

;; Data Maps
(define-map drainage-systems
  { drain-id: uint }
  {
    operator: principal,
    location: (string-ascii 50),
    capacity-liters: uint,
    current-flow: uint,
    efficiency-rating: uint,
    active: bool,
    last-optimized: uint,
    maintenance-due: uint
  }
)

(define-map optimization-history
  { drain-id: uint, optimization-id: uint }
  {
    before-efficiency: uint,
    after-efficiency: uint,
    improvement: uint,
    timestamp: uint,
    operator: principal
  }
)

(define-map flow-measurements
  { drain-id: uint, measurement-id: uint }
  {
    timestamp: uint,
    flow-rate: uint,
    water-level: uint,
    debris-level: uint,
    operator: principal
  }
)

(define-map operator-stats
  { operator: principal }
  {
    drains-managed: uint,
    total-optimizations: uint,
    efficiency-score: uint,
    rewards-earned: uint
  }
)

;; Helper function to calculate minimum of two values
(define-private (min-val (a uint) (b uint))
  (if (<= a b) a b)
)

;; Helper function to calculate maximum of two values
(define-private (max-val (a uint) (b uint))
  (if (>= a b) a b)
)

;; Register a new drainage system
(define-public (register-drainage-system
  (location (string-ascii 50))
  (capacity-liters uint))
  (let
    (
      (drain-id (+ (var-get total-drains) u1))
      (existing-operator (default-to
        { drains-managed: u0, total-optimizations: u0, efficiency-score: u100, rewards-earned: u0 }
        (map-get? operator-stats { operator: tx-sender })
      ))
    )
    (asserts! (is-none (map-get? drainage-systems { drain-id: drain-id })) ERR_DRAIN_EXISTS)
    (asserts! (> capacity-liters u0) ERR_INVALID_DATA)
    (asserts! (<= capacity-liters u100000) ERR_INVALID_DATA) ;; Max 100,000 liters

    (map-set drainage-systems
      { drain-id: drain-id }
      {
        operator: tx-sender,
        location: location,
        capacity-liters: capacity-liters,
        current-flow: u0,
        efficiency-rating: u75, ;; Start with 75% efficiency
        active: true,
        last-optimized: block-height,
        maintenance-due: (+ block-height u1000) ;; Due in 1000 blocks
      }
    )

    (map-set operator-stats
      { operator: tx-sender }
      (merge existing-operator {
        drains-managed: (+ (get drains-managed existing-operator) u1)
      })
    )

    (var-set total-drains drain-id)
    (ok drain-id)
  )
)

;; Record flow measurement
(define-public (record-flow-measurement
  (drain-id uint)
  (flow-rate uint)
  (water-level uint)
  (debris-level uint))
  (let
    (
      (drain (unwrap! (map-get? drainage-systems { drain-id: drain-id }) ERR_DRAIN_NOT_FOUND))
      (measurement-id (+ (get current-flow drain) u1))
    )
    (asserts! (is-eq tx-sender (get operator drain)) ERR_UNAUTHORIZED)
    (asserts! (get active drain) ERR_INVALID_DATA)
    (asserts! (<= flow-rate (get capacity-liters drain)) ERR_INVALID_DATA)
    (asserts! (<= water-level u100) ERR_INVALID_DATA) ;; Max 100% water level
    (asserts! (<= debris-level u100) ERR_INVALID_DATA) ;; Max 100% debris level

    (map-set flow-measurements
      { drain-id: drain-id, measurement-id: measurement-id }
      {
        timestamp: block-height,
        flow-rate: flow-rate,
        water-level: water-level,
        debris-level: debris-level,
        operator: tx-sender
      }
    )

    (map-set drainage-systems
      { drain-id: drain-id }
      (merge drain {
        current-flow: flow-rate
      })
    )

    (ok measurement-id)
  )
)

;; Optimize drainage system
(define-public (optimize-drainage (drain-id uint) (optimization-type uint))
  (let
    (
      (drain (unwrap! (map-get? drainage-systems { drain-id: drain-id }) ERR_DRAIN_NOT_FOUND))
      (current-efficiency (get efficiency-rating drain))
      (improvement-factor (+ u10 (* optimization-type u5)))
      (new-efficiency (min-val u100 (+ current-efficiency improvement-factor)))
      (improvement (- new-efficiency current-efficiency))
      (operator-data (unwrap! (map-get? operator-stats { operator: tx-sender }) ERR_DRAIN_NOT_FOUND))
      (optimization-id (+ (get total-optimizations operator-data) u1))
    )
    (asserts! (is-eq tx-sender (get operator drain)) ERR_UNAUTHORIZED)
    (asserts! (get active drain) ERR_INVALID_DATA)
    (asserts! (< optimization-type u5) ERR_INVALID_DATA)

    (map-set drainage-systems
      { drain-id: drain-id }
      (merge drain {
        efficiency-rating: new-efficiency,
        last-optimized: block-height
      })
    )

    (map-set optimization-history
      { drain-id: drain-id, optimization-id: optimization-id }
      {
        before-efficiency: current-efficiency,
        after-efficiency: new-efficiency,
        improvement: improvement,
        timestamp: block-height,
        operator: tx-sender
      }
    )

    (map-set operator-stats
      { operator: tx-sender }
      (merge operator-data {
        total-optimizations: optimization-id,
        efficiency-score: (+ (get efficiency-score operator-data) improvement),
        rewards-earned: (+ (get rewards-earned operator-data) (var-get optimization-reward))
      })
    )

    (try! (ft-mint? drainage-token (var-get optimization-reward) tx-sender))
    (ok improvement)
  )
)

;; Calculate system efficiency
(define-private (calculate-efficiency (flow-rate uint) (capacity uint) (debris-level uint))
  (let
    (
      (flow-ratio (/ (* flow-rate u100) capacity))
      (debris-penalty (/ debris-level u2))
      (base-efficiency (- u100 debris-penalty))
    )
    (if (> flow-ratio u80)
      (- base-efficiency u20) ;; Penalty for over-capacity
      base-efficiency
    )
  )
)

;; Deactivate drainage system
(define-public (deactivate-drainage-system (drain-id uint))
  (let
    (
      (drain (unwrap! (map-get? drainage-systems { drain-id: drain-id }) ERR_DRAIN_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get operator drain)) ERR_UNAUTHORIZED)

    (map-set drainage-systems
      { drain-id: drain-id }
      (merge drain { active: false })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-drainage-system (drain-id uint))
  (map-get? drainage-systems { drain-id: drain-id })
)

(define-read-only (get-optimization-history (drain-id uint) (optimization-id uint))
  (map-get? optimization-history { drain-id: drain-id, optimization-id: optimization-id })
)

(define-read-only (get-flow-measurement (drain-id uint) (measurement-id uint))
  (map-get? flow-measurements { drain-id: drain-id, measurement-id: measurement-id })
)

(define-read-only (get-operator-stats (operator principal))
  (map-get? operator-stats { operator: operator })
)

(define-read-only (get-total-drains)
  (var-get total-drains)
)

(define-read-only (get-total-optimizations)
  (var-get total-optimizations)
)

(define-read-only (get-token-balance (account principal))
  (ft-get-balance drainage-token account)
)
