;; Environmental Protection Contract
;; Prevents contaminated runoff from reaching waterways

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_MONITOR_EXISTS (err u501))
(define-constant ERR_MONITOR_NOT_FOUND (err u502))
(define-constant ERR_INVALID_DATA (err u503))
(define-constant ERR_INVALID_LEVEL (err u504))

;; Data Variables
(define-data-var total-monitors uint u0)
(define-data-var total-readings uint u0)
(define-data-var monitoring-reward uint u12)
(define-data-var compliance-bonus uint u18)
(define-data-var pollution-threshold uint u75)

;; Define fungible token for rewards
(define-fungible-token environmental-token)

;; Data Maps
(define-map water-quality-monitors
  { monitor-id: uint }
  {
    operator: principal,
    location: (string-ascii 50),
    monitor-type: uint, ;; 1=inlet, 2=outlet, 3=treatment, 4=discharge
    active: bool,
    last-reading: uint,
    total-readings: uint,
    compliance-score: uint
  }
)

(define-map quality-readings
  { monitor-id: uint, reading-id: uint }
  {
    timestamp: uint,
    ph-level: uint, ;; pH * 10 (60-90 for 6.0-9.0)
    dissolved-oxygen: uint, ;; mg/L * 10
    turbidity: uint, ;; NTU
    chemical-pollutants: uint, ;; ppm * 10
    bacterial-count: uint, ;; CFU/100ml
    temperature: uint, ;; Celsius * 10
    operator: principal
  }
)

(define-map pollution-incidents
  { incident-id: uint }
  {
    reporter: principal,
    location: (string-ascii 50),
    severity: uint, ;; 1=minor, 2=moderate, 3=major, 4=critical
    pollutant-type: uint, ;; 1=chemical, 2=biological, 3=physical, 4=thermal
    estimated-volume: uint,
    source-identified: bool,
    cleanup-status: uint, ;; 1=reported, 2=responding, 3=cleaning, 4=completed
    report-time: uint,
    response-time: uint,
    cleanup-time: uint
  }
)

(define-map treatment-systems
  { system-id: uint }
  {
    operator: principal,
    location: (string-ascii 50),
    treatment-type: uint, ;; 1=filtration, 2=chemical, 3=biological, 4=combined
    capacity: uint, ;; liters per hour
    efficiency-rating: uint,
    active: bool,
    last-maintenance: uint,
    total-treated: uint
  }
)

(define-map operator-environmental-stats
  { operator: principal }
  {
    monitors-operated: uint,
    total-readings: uint,
    incidents-reported: uint,
    compliance-rate: uint,
    environmental-score: uint,
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

;; Register water quality monitor
(define-public (register-water-monitor
  (location (string-ascii 50))
  (monitor-type uint))
  (let
    (
      (monitor-id (+ (var-get total-monitors) u1))
      (existing-operator (default-to
        { monitors-operated: u0, total-readings: u0, incidents-reported: u0, compliance-rate: u100, environmental-score: u100, rewards-earned: u0 }
        (map-get? operator-environmental-stats { operator: tx-sender })
      ))
    )
    (asserts! (is-none (map-get? water-quality-monitors { monitor-id: monitor-id })) ERR_MONITOR_EXISTS)
    (asserts! (<= monitor-type u4) ERR_INVALID_DATA)

    (map-set water-quality-monitors
      { monitor-id: monitor-id }
      {
        operator: tx-sender,
        location: location,
        monitor-type: monitor-type,
        active: true,
        last-reading: u0,
        total-readings: u0,
        compliance-score: u100
      }
    )

    (map-set operator-environmental-stats
      { operator: tx-sender }
      (merge existing-operator {
        monitors-operated: (+ (get monitors-operated existing-operator) u1)
      })
    )

    (var-set total-monitors monitor-id)
    (ok monitor-id)
  )
)

;; Submit water quality reading
(define-public (submit-quality-reading
  (monitor-id uint)
  (ph uint)
  (oxygen uint)
  (turbidity uint)
  (chemicals uint)
  (bacteria uint)
  (temperature uint))
  (let
    (
      (monitor (unwrap! (map-get? water-quality-monitors { monitor-id: monitor-id }) ERR_MONITOR_NOT_FOUND))
      (reading-id (+ (get total-readings monitor) u1))
      (operator-data (unwrap! (map-get? operator-environmental-stats { operator: tx-sender }) ERR_MONITOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get operator monitor)) ERR_UNAUTHORIZED)
    (asserts! (get active monitor) ERR_INVALID_DATA)
    (asserts! (and (>= ph u40) (<= ph u100)) ERR_INVALID_LEVEL) ;; pH 4.0-10.0
    (asserts! (<= oxygen u200) ERR_INVALID_LEVEL) ;; Max 20 mg/L
    (asserts! (<= turbidity u1000) ERR_INVALID_LEVEL) ;; Max 100 NTU
    (asserts! (<= chemicals u5000) ERR_INVALID_LEVEL) ;; Max 500 ppm
    (asserts! (<= bacteria u50000) ERR_INVALID_LEVEL) ;; Max 5000 CFU/100ml
    (asserts! (<= temperature u500) ERR_INVALID_LEVEL) ;; 0-50C * 10

    (map-set quality-readings
      { monitor-id: monitor-id, reading-id: reading-id }
      {
        timestamp: block-height,
        ph-level: ph,
        dissolved-oxygen: oxygen,
        turbidity: turbidity,
        chemical-pollutants: chemicals,
        bacterial-count: bacteria,
        temperature: temperature,
        operator: tx-sender
      }
    )

    (map-set water-quality-monitors
      { monitor-id: monitor-id }
      (merge monitor {
        last-reading: block-height,
        total-readings: reading-id
      })
    )

    (map-set operator-environmental-stats
      { operator: tx-sender }
      (merge operator-data {
        total-readings: (+ (get total-readings operator-data) u1),
        rewards-earned: (+ (get rewards-earned operator-data) (var-get monitoring-reward))
      })
    )

    (var-set total-readings (+ (var-get total-readings) u1))
    (try! (ft-mint? environmental-token (var-get monitoring-reward) tx-sender))

    ;; Check for compliance and award bonus
    (let
      (
        (compliance-check (check-water-compliance ph oxygen turbidity chemicals bacteria temperature))
      )
      (if compliance-check
        (begin
          (try! (ft-mint? environmental-token (var-get compliance-bonus) tx-sender))
          (map-set operator-environmental-stats
            { operator: tx-sender }
            (merge operator-data {
              rewards-earned: (+ (get rewards-earned operator-data) (+ (var-get monitoring-reward) (var-get compliance-bonus)))
            })
          )
        )
        true
      )
    )

    (ok reading-id)
  )
)

;; Check water quality compliance
(define-private (check-water-compliance (ph uint) (oxygen uint) (turbidity uint) (chemicals uint) (bacteria uint) (temp uint))
  (and
    (and (>= ph u60) (<= ph u90)) ;; pH 6.0-9.0
    (>= oxygen u50) ;; Min 5 mg/L dissolved oxygen
    (<= turbidity u50) ;; Max 5 NTU turbidity
    (<= chemicals u100) ;; Max 10 ppm chemicals
    (<= bacteria u1000) ;; Max 100 CFU/100ml bacteria
    (and (>= temp u50) (<= temp u300)) ;; 5-30C temperature range
  )
)

;; Report pollution incident
(define-public (report-pollution-incident
  (location (string-ascii 50))
  (severity uint)
  (pollutant-type uint)
  (estimated-volume uint))
  (let
    (
      (incident-id (+ (var-get total-readings) u1)) ;; Reusing counter for simplicity
      (existing-operator (default-to
        { monitors-operated: u0, total-readings: u0, incidents-reported: u0, compliance-rate: u100, environmental-score: u100, rewards-earned: u0 }
        (map-get? operator-environmental-stats { operator: tx-sender })
      ))
    )
    (asserts! (<= severity u4) ERR_INVALID_DATA)
    (asserts! (<= pollutant-type u4) ERR_INVALID_DATA)

    (map-set pollution-incidents
      { incident-id: incident-id }
      {
        reporter: tx-sender,
        location: location,
        severity: severity,
        pollutant-type: pollutant-type,
        estimated-volume: estimated-volume,
        source-identified: false,
        cleanup-status: u1, ;; Reported
        report-time: block-height,
        response-time: u0,
        cleanup-time: u0
      }
    )

    (map-set operator-environmental-stats
      { operator: tx-sender }
      (merge existing-operator {
        incidents-reported: (+ (get incidents-reported existing-operator) u1),
        environmental-score: (+ (get environmental-score existing-operator) u5),
        rewards-earned: (+ (get rewards-earned existing-operator) (* severity u5))
      })
    )

    (try! (ft-mint? environmental-token (* severity u5) tx-sender))
    (ok incident-id)
  )
)

;; Calculate pollution severity score
(define-private (calculate-pollution-severity (ph uint) (oxygen uint) (turbidity uint) (chemicals uint) (bacteria uint) (temp uint))
  (let
    (
      (ph-severity (if (or (< ph u60) (> ph u90)) u3 (if (or (< ph u65) (> ph u85)) u2 u1)))
      (oxygen-severity (if (< oxygen u30) u3 (if (< oxygen u50) u2 u1)))
      (turbidity-severity (if (> turbidity u80) u3 (if (> turbidity u40) u2 u1)))
      (chemical-severity (if (> chemicals u200) u3 (if (> chemicals u100) u2 u1)))
      (bacteria-severity (if (> bacteria u2000) u3 (if (> bacteria u1000) u2 u1)))
      (temp-severity (if (or (< temp u20) (> temp u350)) u3 (if (or (< temp u50) (> temp u300)) u2 u1)))
    )
    (max-val ph-severity (max-val oxygen-severity (max-val turbidity-severity (max-val chemical-severity (max-val bacteria-severity temp-severity)))))
  )
)

;; Register treatment system
(define-public (register-treatment-system
  (location (string-ascii 50))
  (treatment-type uint)
  (capacity uint))
  (let
    (
      (system-id (+ (var-get total-monitors) u1)) ;; Reusing counter
    )
    (asserts! (<= treatment-type u4) ERR_INVALID_DATA)
    (asserts! (> capacity u0) ERR_INVALID_DATA)

    (map-set treatment-systems
      { system-id: system-id }
      {
        operator: tx-sender,
        location: location,
        treatment-type: treatment-type,
        capacity: capacity,
        efficiency-rating: u85, ;; Start with 85% efficiency
        active: true,
        last-maintenance: block-height,
        total-treated: u0
      }
    )

    (ok system-id)
  )
)

;; Deactivate monitor
(define-public (deactivate-monitor (monitor-id uint))
  (let
    (
      (monitor (unwrap! (map-get? water-quality-monitors { monitor-id: monitor-id }) ERR_MONITOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get operator monitor)) ERR_UNAUTHORIZED)

    (map-set water-quality-monitors
      { monitor-id: monitor-id }
      (merge monitor { active: false })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-water-monitor (monitor-id uint))
  (map-get? water-quality-monitors { monitor-id: monitor-id })
)

(define-read-only (get-quality-reading (monitor-id uint) (reading-id uint))
  (map-get? quality-readings { monitor-id: monitor-id, reading-id: reading-id })
)

(define-read-only (get-pollution-incident (incident-id uint))
  (map-get? pollution-incidents { incident-id: incident-id })
)

(define-read-only (get-treatment-system (system-id uint))
  (map-get? treatment-systems { system-id: system-id })
)

(define-read-only (get-operator-environmental-stats (operator principal))
  (map-get? operator-environmental-stats { operator: operator })
)

(define-read-only (get-total-monitors)
  (var-get total-monitors)
)

(define-read-only (get-total-readings)
  (var-get total-readings)
)

(define-read-only (get-token-balance (account principal))
  (ft-get-balance environmental-token account)
)
