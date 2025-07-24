package grok_recommender

import (
	"encoding/json"
	"time"
)

// Core telemetry data types

// TraceSpan represents a trace span in the telemetry data
type TraceSpan struct {
	TraceID      string            `json:"trace_id"`
	SpanID       string            `json:"span_id"`
	Name         string            `json:"name"`
	Service      string            `json:"service"`
	Duration     time.Duration     `json:"duration"`
	Status       string            `json:"status"`
	Attributes   map[string]string `json:"attributes"`
	ResourceTags map[string]string `json:"resource_tags"`
	Timestamp    time.Time         `json:"timestamp"`
	Kind         string            `json:"kind"`
	ParentSpanID string            `json:"parent_span_id,omitempty"`
}

// MetricDataPoint represents a metric data point
type MetricDataPoint struct {
	Name      string            `json:"name"`
	Value     float64           `json:"value"`
	Type      string            `json:"type"` // gauge, counter, histogram, summary
	Labels    map[string]string `json:"labels"`
	Timestamp time.Time         `json:"timestamp"`
	Unit      string            `json:"unit,omitempty"`
}

// LogEntry represents a log entry
type LogEntry struct {
	Level      string            `json:"level"`
	Message    string            `json:"message"`
	Service    string            `json:"service"`
	Attributes map[string]string `json:"attributes"`
	Timestamp  time.Time         `json:"timestamp"`
	TraceID    string            `json:"trace_id,omitempty"`
	SpanID     string            `json:"span_id,omitempty"`
}

// TelemetrySample represents a sample of telemetry data
type TelemetrySample struct {
	Traces  []TraceSpan       `json:"traces"`
	Metrics []MetricDataPoint `json:"metrics"`
	Logs    []LogEntry        `json:"logs"`
	Meta    SampleMetadata    `json:"meta"`
}

// SampleMetadata contains metadata about the sample
type SampleMetadata struct {
	TotalSpans      int       `json:"total_spans"`
	TotalMetrics    int       `json:"total_metrics"`
	TotalLogs       int       `json:"total_logs"`
	Services        []string  `json:"services"`
	SampleStartTime time.Time `json:"sample_start_time"`
	SampleEndTime   time.Time `json:"sample_end_time"`
	Version         string    `json:"version"`
}

// ToJSON converts the sample to JSON string
func (ts *TelemetrySample) ToJSON() (string, error) {
	data, err := json.Marshal(ts)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// Recommendation types

// RecommendationType represents different types of recommendations
type RecommendationType string

const (
	RecommendationTypeDropSignal    RecommendationType = "drop_signal"
	RecommendationTypeLabelPolicy   RecommendationType = "label_policy"
	RecommendationTypeOptimization  RecommendationType = "optimization"
	RecommendationTypeSampling      RecommendationType = "sampling"
	RecommendationTypeAggregation   RecommendationType = "aggregation"
)

// Priority represents recommendation priority
type Priority string

const (
	PriorityCritical Priority = "critical"
	PriorityHigh     Priority = "high"
	PriorityMedium   Priority = "medium"
	PriorityLow      Priority = "low"
)

// SignalType represents the type of telemetry signal
type SignalType string

const (
	SignalTypeTrace  SignalType = "trace"
	SignalTypeMetric SignalType = "metric"
	SignalTypeLog    SignalType = "log"
)

// Recommendation represents a single recommendation
type Recommendation struct {
	ID          string             `json:"id"`
	Type        RecommendationType `json:"type"`
	Priority    Priority           `json:"priority"`
	Description string             `json:"description"`
	Rationale   string             `json:"rationale"`
	FilterRules []FilterRule       `json:"filter_rules"`
	Impact      Impact             `json:"impact"`
	CreatedAt   time.Time          `json:"created_at"`
	ExpiresAt   time.Time          `json:"expires_at,omitempty"`
}

// FilterRule represents an OpenTelemetry filter rule
type FilterRule struct {
	Name        string     `json:"name"`
	Type        SignalType `json:"type"`
	Condition   string     `json:"condition"`
	Action      string     `json:"action"` // drop, allow, modify
	Description string     `json:"description"`
	Priority    int        `json:"priority"`
}

// Impact represents the expected impact of a recommendation
type Impact struct {
	DataVolumeReduction string  `json:"data_volume_reduction"`
	CostSavings         string  `json:"cost_savings"`
	PerformanceGain     string  `json:"performance_gain"`
	ConfidenceScore     float64 `json:"confidence_score"`
}

// ParsedRecommendations represents parsed recommendations from Grok
type ParsedRecommendations struct {
	Recommendations []Recommendation `json:"recommendations"`
	Summary         Summary          `json:"summary"`
	GeneratedAt     time.Time        `json:"generated_at"`
	Source          string           `json:"source"`
	Version         string           `json:"version"`
}

// Summary provides a summary of recommendations
type Summary struct {
	TotalRecommendations int                           `json:"total_recommendations"`
	ByType               map[RecommendationType]int    `json:"by_type"`
	ByPriority           map[Priority]int              `json:"by_priority"`
	EstimatedSavings     string                        `json:"estimated_savings"`
	HighestPriority      Priority                      `json:"highest_priority"`
	RecommendedActions   []string                      `json:"recommended_actions"`
}

// Health and monitoring types

// HealthStatus represents the health status of a component
type HealthStatus string

const (
	HealthStatusHealthy   HealthStatus = "healthy"
	HealthStatusDegraded  HealthStatus = "degraded"
	HealthStatusUnhealthy HealthStatus = "unhealthy"
	HealthStatusUnknown   HealthStatus = "unknown"
)

// HealthReport represents a health check report
type HealthReport struct {
	Status        HealthStatus       `json:"status"`
	LastCheck     time.Time          `json:"last_check"`
	APIConnected  bool               `json:"api_connected"`
	CacheHealth   HealthStatus       `json:"cache_health"`
	MetricsHealth HealthStatus       `json:"metrics_health"`
	Details       map[string]string  `json:"details"`
	Errors        []string           `json:"errors,omitempty"`
}

// Circuit breaker types

// CircuitState represents the state of a circuit breaker
type CircuitState string

const (
	CircuitStateClosed   CircuitState = "closed"
	CircuitStateOpen     CircuitState = "open"
	CircuitStateHalfOpen CircuitState = "half_open"
)

// CircuitBreakerConfig contains circuit breaker configuration
type CircuitBreakerConfig struct {
	MaxFailures   int           `json:"max_failures"`
	Timeout       time.Duration `json:"timeout"`
	ResetInterval time.Duration `json:"reset_interval"`
}

// Configuration types

// ProcessorMetrics contains metrics for the processor
type ProcessorMetrics struct {
	RequestsTotal         int64   `json:"requests_total"`
	RequestsSuccessful    int64   `json:"requests_successful"`
	RequestsFailed        int64   `json:"requests_failed"`
	CacheHits             int64   `json:"cache_hits"`
	CacheMisses           int64   `json:"cache_misses"`
	RecommendationsTotal  int64   `json:"recommendations_total"`
	FiltersApplied        int64   `json:"filters_applied"`
	PolicyViolations      int64   `json:"policy_violations"`
	AverageResponseTime   float64 `json:"average_response_time_ms"`
	LastUpdateTime        time.Time `json:"last_update_time"`
}

// ValidationError represents a validation error
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
	Code    string `json:"code"`
}

// ValidationResult represents the result of validation
type ValidationResult struct {
	Valid  bool              `json:"valid"`
	Errors []ValidationError `json:"errors,omitempty"`
}

// AsyncJob represents an asynchronous job
type AsyncJob struct {
	ID        string                 `json:"id"`
	Type      string                 `json:"type"`
	Status    string                 `json:"status"`
	Payload   map[string]interface{} `json:"payload"`
	CreatedAt time.Time              `json:"created_at"`
	UpdatedAt time.Time              `json:"updated_at"`
}

// JobResult represents the result of an asynchronous job
type JobResult struct {
	JobID     string                 `json:"job_id"`
	Success   bool                   `json:"success"`
	Result    interface{}            `json:"result,omitempty"`
	Error     string                 `json:"error,omitempty"`
	Duration  time.Duration          `json:"duration"`
	CompletedAt time.Time            `json:"completed_at"`
}