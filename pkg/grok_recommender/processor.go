package grok_recommender

import (
	"context"
	"fmt"
	"os"
	"sync"
	"time"
)

// GrokRecommenderProcessor implements an OTel processor that uses Grok for recommendations
type GrokRecommenderProcessor struct {
	config               *ProcessorConfig
	recommender          *Recommender
	activeRecommendations *ParsedRecommendations
	mutex                sync.RWMutex
	stopCh               chan struct{}
	logger               *logger
	telemetryBuffer      *TelemetryBuffer
	policyManager        *PolicyManager
	filterManager        *FilterManager
}

// ProcessorConfig contains configuration for the processor
type ProcessorConfig struct {
	// Grok API settings
	APIKey           string        `mapstructure:"api_key"`
	MaxSampleSize    int           `mapstructure:"max_sample_size"`
	SamplingInterval time.Duration `mapstructure:"sampling_interval"`
	
	// Cache and rate limiting
	EnableCache       bool          `mapstructure:"enable_cache"`
	CacheExpiration   time.Duration `mapstructure:"cache_expiration"`
	RateLimitRPM      int           `mapstructure:"rate_limit_rpm"`
	EnableRateLimit   bool          `mapstructure:"enable_rate_limit"`
	
	// Fallback and error handling
	FallbackToStatic  bool          `mapstructure:"fallback_to_static"`
	LogLevel          string        `mapstructure:"log_level"`
	
	// Policy management
	PolicyFile        string        `mapstructure:"policy_file"`
	RequiredLabels    []string      `mapstructure:"required_labels"`
	ForbiddenLabels   []string      `mapstructure:"forbidden_labels"`
	
	// Filter application
	AutoApplyFilters  bool          `mapstructure:"auto_apply_filters"`
	MaxFilterRules    int           `mapstructure:"max_filter_rules"`
	FilterTimeout     time.Duration `mapstructure:"filter_timeout"`
	
	// Monitoring
	MetricsEnabled    bool          `mapstructure:"metrics_enabled"`
	MetricsInterval   time.Duration `mapstructure:"metrics_interval"`
}

// TelemetryBuffer buffers telemetry data for sampling
type TelemetryBuffer struct {
	traces  []TraceSpan
	metrics []MetricDataPoint
	logs    []LogEntry
	mutex   sync.RWMutex
	maxSize int
}

// PolicyManager manages label policies
type PolicyManager struct {
	policies      []LabelPolicy
	policyFile    string
	lastModified  time.Time
	mutex         sync.RWMutex
}

// FilterManager manages dynamic filter rules
type FilterManager struct {
	activeFilters    []FilterRule
	appliedFilters   map[string]bool
	mutex           sync.RWMutex
	maxRules        int
	filterTimeout   time.Duration
}

// logger provides structured logging
type logger struct {
	level string
}

// NewGrokRecommenderProcessor creates a new Grok recommender processor
func NewGrokRecommenderProcessor(config *ProcessorConfig) (*GrokRecommenderProcessor, error) {
	// Set defaults
	if config.MaxSampleSize == 0 {
		config.MaxSampleSize = 100
	}
	if config.SamplingInterval == 0 {
		config.SamplingInterval = time.Minute * 5
	}
	if config.CacheExpiration == 0 {
		config.CacheExpiration = time.Hour
	}
	if config.RateLimitRPM == 0 {
		config.RateLimitRPM = 60
	}
	if config.MaxFilterRules == 0 {
		config.MaxFilterRules = 100
	}
	if config.FilterTimeout == 0 {
		config.FilterTimeout = time.Second * 10
	}
	if config.MetricsInterval == 0 {
		config.MetricsInterval = time.Minute
	}
	
	// Get API key from environment if not provided
	if config.APIKey == "" {
		config.APIKey = os.Getenv("GROK_API_KEY")
	}
	
	if config.APIKey == "" {
		return nil, fmt.Errorf("GROK_API_KEY environment variable or api_key config must be set")
	}
	
	// Create recommender
	recommenderConfig := &RecommenderConfig{
		APIKey:           config.APIKey,
		MaxSampleSize:    config.MaxSampleSize,
		SamplingInterval: config.SamplingInterval,
		CacheExpiration:  config.CacheExpiration,
		RateLimitRPM:     config.RateLimitRPM,
		EnableCache:      config.EnableCache,
		EnableRateLimit:  config.EnableRateLimit,
		FallbackToStatic: config.FallbackToStatic,
		LogLevel:         config.LogLevel,
		PolicyFile:       config.PolicyFile,
	}
	
	recommender, err := NewRecommender(recommenderConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create recommender: %w", err)
	}
	
	// Create telemetry buffer
	telemetryBuffer := &TelemetryBuffer{
		traces:  make([]TraceSpan, 0),
		metrics: make([]MetricDataPoint, 0),
		logs:    make([]LogEntry, 0),
		maxSize: config.MaxSampleSize * 10, // Buffer 10x the sample size
	}
	
	// Create policy manager
	policyManager := &PolicyManager{
		policies:   make([]LabelPolicy, 0),
		policyFile: config.PolicyFile,
	}
	
	// Create filter manager
	filterManager := &FilterManager{
		activeFilters:  make([]FilterRule, 0),
		appliedFilters: make(map[string]bool),
		maxRules:      config.MaxFilterRules,
		filterTimeout: config.FilterTimeout,
	}
	
	// Create logger
	logger := &logger{level: config.LogLevel}
	
	processor := &GrokRecommenderProcessor{
		config:          config,
		recommender:     recommender,
		stopCh:          make(chan struct{}),
		logger:          logger,
		telemetryBuffer: telemetryBuffer,
		policyManager:   policyManager,
		filterManager:   filterManager,
	}
	
	// Load initial policies
	if err := processor.loadPolicies(); err != nil {
		processor.logger.Warn("Failed to load initial policies: %v", err)
	}
	
	return processor, nil
}

// Start starts the processor background tasks
func (p *GrokRecommenderProcessor) Start(ctx context.Context) error {
	p.logger.Info("Starting Grok recommender processor")
	
	// Validate API connection
	if err := p.recommender.ValidateConnection(ctx); err != nil {
		if !p.config.FallbackToStatic {
			return fmt.Errorf("failed to validate Grok API connection: %w", err)
		}
		p.logger.Warn("Grok API connection failed, will use static recommendations: %v", err)
	}
	
	// Start periodic recommendation generation
	go p.runRecommendationLoop(ctx)
	
	// Start policy monitoring
	go p.monitorPolicies(ctx)
	
	// Start metrics collection if enabled
	if p.config.MetricsEnabled {
		go p.collectMetrics(ctx)
	}
	
	return nil
}

// Stop stops the processor
func (p *GrokRecommenderProcessor) Stop() {
	p.logger.Info("Stopping Grok recommender processor")
	close(p.stopCh)
}

// ProcessTraces processes trace data
func (p *GrokRecommenderProcessor) ProcessTraces(ctx context.Context, traces []TraceSpan) ([]TraceSpan, error) {
	// Buffer traces for sampling
	p.bufferTraces(traces)
	
	// Apply active filters
	filtered := p.applyTraceFilters(traces)
	
	return filtered, nil
}

// ProcessMetrics processes metric data
func (p *GrokRecommenderProcessor) ProcessMetrics(ctx context.Context, metrics []MetricDataPoint) ([]MetricDataPoint, error) {
	// Buffer metrics for sampling
	p.bufferMetrics(metrics)
	
	// Apply active filters
	filtered := p.applyMetricFilters(metrics)
	
	return filtered, nil
}

// ProcessLogs processes log data
func (p *GrokRecommenderProcessor) ProcessLogs(ctx context.Context, logs []LogEntry) ([]LogEntry, error) {
	// Buffer logs for sampling
	p.bufferLogs(logs)
	
	// Apply active filters
	filtered := p.applyLogFilters(logs)
	
	return filtered, nil
}

// runRecommendationLoop runs the main recommendation generation loop
func (p *GrokRecommenderProcessor) runRecommendationLoop(ctx context.Context) {
	ticker := time.NewTicker(p.config.SamplingInterval)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			return
		case <-p.stopCh:
			return
		case <-ticker.C:
			if err := p.generateRecommendations(ctx); err != nil {
				p.logger.Error("Failed to generate recommendations: %v", err)
			}
		}
	}
}

// generateRecommendations generates new recommendations
func (p *GrokRecommenderProcessor) generateRecommendations(ctx context.Context) error {
	p.logger.Debug("Generating recommendations")
	
	// Get sample from buffer
	sample := p.getSampleFromBuffer()
	if sample == nil {
		p.logger.Debug("No telemetry data available for sampling")
		return nil
	}
	
	// Get current policies
	policies := p.policyManager.GetPolicies()
	
	// Generate recommendations
	recommendations, err := p.recommender.GenerateRecommendations(ctx, sample, policies)
	if err != nil {
		return fmt.Errorf("failed to generate recommendations: %w", err)
	}
	
	// Update active recommendations
	p.mutex.Lock()
	p.activeRecommendations = recommendations
	p.mutex.Unlock()
	
	// Apply filters if auto-apply is enabled
	if p.config.AutoApplyFilters {
		p.applyRecommendedFilters(recommendations)
	}
	
	p.logger.Info("Generated %d recommendations", len(recommendations.Recommendations))
	
	return nil
}

// getSampleFromBuffer creates a sample from the telemetry buffer
func (p *GrokRecommenderProcessor) getSampleFromBuffer() *TelemetrySample {
	p.telemetryBuffer.mutex.RLock()
	defer p.telemetryBuffer.mutex.RUnlock()
	
	if len(p.telemetryBuffer.traces) == 0 && 
		len(p.telemetryBuffer.metrics) == 0 && 
		len(p.telemetryBuffer.logs) == 0 {
		return nil
	}
	
	// Create copies to avoid race conditions
	traces := make([]TraceSpan, len(p.telemetryBuffer.traces))
	copy(traces, p.telemetryBuffer.traces)
	
	metrics := make([]MetricDataPoint, len(p.telemetryBuffer.metrics))
	copy(metrics, p.telemetryBuffer.metrics)
	
	logs := make([]LogEntry, len(p.telemetryBuffer.logs))
	copy(logs, p.telemetryBuffer.logs)
	
	return p.recommender.sampler.CreateSample(traces, metrics, logs)
}

// bufferTraces adds traces to the buffer
func (p *GrokRecommenderProcessor) bufferTraces(traces []TraceSpan) {
	p.telemetryBuffer.mutex.Lock()
	defer p.telemetryBuffer.mutex.Unlock()
	
	p.telemetryBuffer.traces = append(p.telemetryBuffer.traces, traces...)
	
	// Trim buffer if it exceeds max size
	if len(p.telemetryBuffer.traces) > p.telemetryBuffer.maxSize {
		p.telemetryBuffer.traces = p.telemetryBuffer.traces[len(p.telemetryBuffer.traces)-p.telemetryBuffer.maxSize:]
	}
}

// bufferMetrics adds metrics to the buffer
func (p *GrokRecommenderProcessor) bufferMetrics(metrics []MetricDataPoint) {
	p.telemetryBuffer.mutex.Lock()
	defer p.telemetryBuffer.mutex.Unlock()
	
	p.telemetryBuffer.metrics = append(p.telemetryBuffer.metrics, metrics...)
	
	// Trim buffer if it exceeds max size
	if len(p.telemetryBuffer.metrics) > p.telemetryBuffer.maxSize {
		p.telemetryBuffer.metrics = p.telemetryBuffer.metrics[len(p.telemetryBuffer.metrics)-p.telemetryBuffer.maxSize:]
	}
}

// bufferLogs adds logs to the buffer
func (p *GrokRecommenderProcessor) bufferLogs(logs []LogEntry) {
	p.telemetryBuffer.mutex.Lock()
	defer p.telemetryBuffer.mutex.Unlock()
	
	p.telemetryBuffer.logs = append(p.telemetryBuffer.logs, logs...)
	
	// Trim buffer if it exceeds max size
	if len(p.telemetryBuffer.logs) > p.telemetryBuffer.maxSize {
		p.telemetryBuffer.logs = p.telemetryBuffer.logs[len(p.telemetryBuffer.logs)-p.telemetryBuffer.maxSize:]
	}
}

// applyRecommendedFilters applies recommended filters
func (p *GrokRecommenderProcessor) applyRecommendedFilters(recommendations *ParsedRecommendations) {
	p.filterManager.mutex.Lock()
	defer p.filterManager.mutex.Unlock()
	
	for _, rec := range recommendations.Recommendations {
		for _, rule := range rec.FilterRules {
			// Check if rule is already applied
			if p.filterManager.appliedFilters[rule.Name] {
				continue
			}
			
			// Check if we have room for more rules
			if len(p.filterManager.activeFilters) >= p.filterManager.maxRules {
				p.logger.Warn("Maximum filter rules reached, skipping rule: %s", rule.Name)
				continue
			}
			
			// Apply the filter
			p.filterManager.activeFilters = append(p.filterManager.activeFilters, rule)
			p.filterManager.appliedFilters[rule.Name] = true
			
			p.logger.Info("Applied filter rule: %s", rule.Name)
		}
	}
}

// applyTraceFilters applies active trace filters
func (p *GrokRecommenderProcessor) applyTraceFilters(traces []TraceSpan) []TraceSpan {
	p.filterManager.mutex.RLock()
	defer p.filterManager.mutex.RUnlock()
	
	filtered := make([]TraceSpan, 0, len(traces))
	
	for _, trace := range traces {
		shouldKeep := true
		
		for _, filter := range p.filterManager.activeFilters {
			if filter.Type == SignalTypeTrace {
				if p.evaluateTraceFilter(trace, filter) {
					shouldKeep = false
					break
				}
			}
		}
		
		if shouldKeep {
			filtered = append(filtered, trace)
		}
	}
	
	return filtered
}

// applyMetricFilters applies active metric filters
func (p *GrokRecommenderProcessor) applyMetricFilters(metrics []MetricDataPoint) []MetricDataPoint {
	p.filterManager.mutex.RLock()
	defer p.filterManager.mutex.RUnlock()
	
	filtered := make([]MetricDataPoint, 0, len(metrics))
	
	for _, metric := range metrics {
		shouldKeep := true
		
		for _, filter := range p.filterManager.activeFilters {
			if filter.Type == SignalTypeMetric {
				if p.evaluateMetricFilter(metric, filter) {
					shouldKeep = false
					break
				}
			}
		}
		
		if shouldKeep {
			filtered = append(filtered, metric)
		}
	}
	
	return filtered
}

// applyLogFilters applies active log filters
func (p *GrokRecommenderProcessor) applyLogFilters(logs []LogEntry) []LogEntry {
	p.filterManager.mutex.RLock()
	defer p.filterManager.mutex.RUnlock()
	
	filtered := make([]LogEntry, 0, len(logs))
	
	for _, log := range logs {
		shouldKeep := true
		
		for _, filter := range p.filterManager.activeFilters {
			if filter.Type == SignalTypeLog {
				if p.evaluateLogFilter(log, filter) {
					shouldKeep = false
					break
				}
			}
		}
		
		if shouldKeep {
			filtered = append(filtered, log)
		}
	}
	
	return filtered
}

// evaluateTraceFilter evaluates a trace against a filter rule
func (p *GrokRecommenderProcessor) evaluateTraceFilter(trace TraceSpan, filter FilterRule) bool {
	// Simple evaluation - in production, this would use OTTL
	condition := filter.Condition
	
	// Check for common patterns
	if condition == `attributes["level"] == "DEBUG"` {
		return trace.Attributes["level"] == "DEBUG"
	}
	
	if condition == `resource.attributes["environment"] == nil` {
		return trace.ResourceTags["environment"] == ""
	}
	
	// Add more filter evaluations as needed
	return false
}

// evaluateMetricFilter evaluates a metric against a filter rule
func (p *GrokRecommenderProcessor) evaluateMetricFilter(metric MetricDataPoint, filter FilterRule) bool {
	// Simple evaluation - in production, this would use OTTL
	condition := filter.Condition
	
	// Check for common patterns
	if condition == `labels["cardinality"] > 1000` {
		// This would require actual cardinality calculation
		return false
	}
	
	// Add more filter evaluations as needed
	return false
}

// evaluateLogFilter evaluates a log against a filter rule
func (p *GrokRecommenderProcessor) evaluateLogFilter(log LogEntry, filter FilterRule) bool {
	// Simple evaluation - in production, this would use OTTL
	condition := filter.Condition
	
	// Check for common patterns
	if condition == `attributes["level"] == "DEBUG"` {
		return log.Level == "DEBUG"
	}
	
	// Add more filter evaluations as needed
	return false
}

// GetActiveRecommendations returns the current active recommendations
func (p *GrokRecommenderProcessor) GetActiveRecommendations() *ParsedRecommendations {
	p.mutex.RLock()
	defer p.mutex.RUnlock()
	
	return p.activeRecommendations
}

// GetActiveFilters returns the current active filters
func (p *GrokRecommenderProcessor) GetActiveFilters() []FilterRule {
	p.filterManager.mutex.RLock()
	defer p.filterManager.mutex.RUnlock()
	
	filters := make([]FilterRule, len(p.filterManager.activeFilters))
	copy(filters, p.filterManager.activeFilters)
	
	return filters
}

// ClearFilters clears all active filters
func (p *GrokRecommenderProcessor) ClearFilters() {
	p.filterManager.mutex.Lock()
	defer p.filterManager.mutex.Unlock()
	
	p.filterManager.activeFilters = make([]FilterRule, 0)
	p.filterManager.appliedFilters = make(map[string]bool)
	
	p.logger.Info("Cleared all active filters")
}

// Helper methods for other components

// loadPolicies loads policies from file
func (p *GrokRecommenderProcessor) loadPolicies() error {
	// Implementation would load from YAML file
	return nil
}

// monitorPolicies monitors policy file for changes
func (p *GrokRecommenderProcessor) monitorPolicies(ctx context.Context) {
	// Implementation would watch file for changes
}

// collectMetrics collects processor metrics
func (p *GrokRecommenderProcessor) collectMetrics(ctx context.Context) {
	// Implementation would collect and export metrics
}

// GetPolicies returns current policies
func (pm *PolicyManager) GetPolicies() []LabelPolicy {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()
	
	policies := make([]LabelPolicy, len(pm.policies))
	copy(policies, pm.policies)
	
	return policies
}

// Simple logger implementation
func (l *logger) Info(msg string, args ...interface{}) {
	fmt.Printf("[INFO] "+msg+"\n", args...)
}

func (l *logger) Warn(msg string, args ...interface{}) {
	fmt.Printf("[WARN] "+msg+"\n", args...)
}

func (l *logger) Error(msg string, args ...interface{}) {
	fmt.Printf("[ERROR] "+msg+"\n", args...)
}

func (l *logger) Debug(msg string, args ...interface{}) {
	if l.level == "debug" {
		fmt.Printf("[DEBUG] "+msg+"\n", args...)
	}
}