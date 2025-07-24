package grok_recommender

import (
	"context"
	"fmt"
	"math"
	"sync"
	"time"
)

// CircuitBreaker implements the circuit breaker pattern for API calls
type CircuitBreaker struct {
	config          CircuitBreakerConfig
	state           CircuitState
	failureCount    int
	lastFailureTime time.Time
	lastSuccessTime time.Time
	nextAttemptTime time.Time
	mutex           sync.RWMutex
	onStateChange   func(from, to CircuitState)
}

// RetryConfig defines retry behavior configuration
type RetryConfig struct {
	MaxAttempts      int           `json:"max_attempts"`
	InitialDelay     time.Duration `json:"initial_delay"`
	MaxDelay         time.Duration `json:"max_delay"`
	BackoffFactor    float64       `json:"backoff_factor"`
	Jitter           bool          `json:"jitter"`
	RetryableErrors  []string      `json:"retryable_errors"`
	NonRetryableErrors []string    `json:"non_retryable_errors"`
}

// ResilienceConfig combines all resilience-related configuration
type ResilienceConfig struct {
	CircuitBreaker CircuitBreakerConfig `json:"circuit_breaker"`
	Retry          RetryConfig          `json:"retry"`
	Timeout        TimeoutConfig        `json:"timeout"`
	Bulkhead       BulkheadConfig       `json:"bulkhead"`
}

// TimeoutConfig defines timeout behavior
type TimeoutConfig struct {
	APITimeout      time.Duration `json:"api_timeout"`
	RequestTimeout  time.Duration `json:"request_timeout"`
	ContextTimeout  time.Duration `json:"context_timeout"`
}

// BulkheadConfig defines resource isolation configuration
type BulkheadConfig struct {
	MaxConcurrentRequests int           `json:"max_concurrent_requests"`
	QueueSize            int           `json:"queue_size"`
	QueueTimeout         time.Duration `json:"queue_timeout"`
}

// ResilienceManager manages all resilience features
type ResilienceManager struct {
	circuitBreaker *CircuitBreaker
	retryConfig    RetryConfig
	timeoutConfig  TimeoutConfig
	bulkhead       *Bulkhead
	metrics        *ResilienceMetrics
	logger         Logger
}

// ResilienceMetrics tracks resilience-related metrics
type ResilienceMetrics struct {
	TotalRequests           int64     `json:"total_requests"`
	SuccessfulRequests      int64     `json:"successful_requests"`
	FailedRequests          int64     `json:"failed_requests"`
	CircuitBreakerTrips     int64     `json:"circuit_breaker_trips"`
	RetryAttempts           int64     `json:"retry_attempts"`
	TimeoutErrors           int64     `json:"timeout_errors"`
	BulkheadRejections      int64     `json:"bulkhead_rejections"`
	LastRequestTime         time.Time `json:"last_request_time"`
	AverageResponseTime     float64   `json:"average_response_time_ms"`
	CircuitBreakerState     string    `json:"circuit_breaker_state"`
	mutex                   sync.RWMutex
}

// Bulkhead provides resource isolation using semaphores
type Bulkhead struct {
	semaphore chan struct{}
	queue     chan *bulkheadRequest
	config    BulkheadConfig
	metrics   *BulkheadMetrics
	ctx       context.Context
	cancel    context.CancelFunc
}

// bulkheadRequest represents a queued request
type bulkheadRequest struct {
	execute  func() error
	result   chan error
	ctx      context.Context
}

// BulkheadMetrics tracks bulkhead-specific metrics
type BulkheadMetrics struct {
	ActiveRequests   int64 `json:"active_requests"`
	QueuedRequests   int64 `json:"queued_requests"`
	RejectedRequests int64 `json:"rejected_requests"`
	mutex            sync.RWMutex
}

// NewCircuitBreaker creates a new circuit breaker
func NewCircuitBreaker(config CircuitBreakerConfig, onStateChange func(from, to CircuitState)) *CircuitBreaker {
	return &CircuitBreaker{
		config:        config,
		state:         CircuitStateClosed,
		onStateChange: onStateChange,
	}
}

// NewResilienceManager creates a new resilience manager
func NewResilienceManager(config ResilienceConfig, logger Logger) *ResilienceManager {
	rm := &ResilienceManager{
		retryConfig:   config.Retry,
		timeoutConfig: config.Timeout,
		metrics:       &ResilienceMetrics{},
		logger:        logger,
	}

	// Initialize circuit breaker
	rm.circuitBreaker = NewCircuitBreaker(config.CircuitBreaker, rm.onCircuitBreakerStateChange)

	// Initialize bulkhead
	rm.bulkhead = NewBulkhead(config.Bulkhead)

	return rm
}

// NewBulkhead creates a new bulkhead
func NewBulkhead(config BulkheadConfig) *Bulkhead {
	ctx, cancel := context.WithCancel(context.Background())
	
	b := &Bulkhead{
		semaphore: make(chan struct{}, config.MaxConcurrentRequests),
		queue:     make(chan *bulkheadRequest, config.QueueSize),
		config:    config,
		metrics:   &BulkheadMetrics{},
		ctx:       ctx,
		cancel:    cancel,
	}

	// Start queue processor
	go b.processQueue()

	return b
}

// Execute executes a function with full resilience features
func (rm *ResilienceManager) Execute(ctx context.Context, operation func() error) error {
	startTime := time.Now()
	
	rm.metrics.mutex.Lock()
	rm.metrics.TotalRequests++
	rm.metrics.LastRequestTime = startTime
	rm.metrics.mutex.Unlock()

	// Apply timeout to context
	if rm.timeoutConfig.ContextTimeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, rm.timeoutConfig.ContextTimeout)
		defer cancel()
	}

	// Execute with bulkhead
	err := rm.bulkhead.Execute(ctx, func() error {
		// Execute with circuit breaker and retry
		return rm.executeWithRetry(ctx, operation)
	})

	// Update metrics
	duration := time.Since(startTime)
	rm.updateMetrics(err, duration)

	return err
}

// executeWithRetry executes an operation with retry logic
func (rm *ResilienceManager) executeWithRetry(ctx context.Context, operation func() error) error {
	var lastErr error
	
	for attempt := 1; attempt <= rm.retryConfig.MaxAttempts; attempt++ {
		// Check circuit breaker
		if !rm.circuitBreaker.CanExecute() {
			return fmt.Errorf("circuit breaker is open: %w", lastErr)
		}

		// Execute operation
		err := rm.circuitBreaker.Execute(operation)
		
		if err == nil {
			if attempt > 1 {
				rm.logger.Info("Operation succeeded after %d attempts", attempt)
			}
			return nil
		}

		lastErr = err
		
		// Check if error is retryable
		if !rm.isRetryableError(err) {
			rm.logger.Debug("Non-retryable error encountered: %v", err)
			return err
		}

		// Don't retry on last attempt
		if attempt == rm.retryConfig.MaxAttempts {
			break
		}

		// Calculate delay
		delay := rm.calculateDelay(attempt)
		
		rm.metrics.mutex.Lock()
		rm.metrics.RetryAttempts++
		rm.metrics.mutex.Unlock()

		rm.logger.Debug("Retrying operation after %v (attempt %d/%d): %v", 
			delay, attempt, rm.retryConfig.MaxAttempts, err)

		// Wait for delay or context cancellation
		select {
		case <-ctx.Done():
			return fmt.Errorf("context cancelled during retry: %w", ctx.Err())
		case <-time.After(delay):
			// Continue to next attempt
		}
	}

	return fmt.Errorf("operation failed after %d attempts: %w", rm.retryConfig.MaxAttempts, lastErr)
}

// CanExecute checks if the circuit breaker allows execution
func (cb *CircuitBreaker) CanExecute() bool {
	cb.mutex.RLock()
	defer cb.mutex.RUnlock()
	
	switch cb.state {
	case CircuitStateClosed:
		return true
	case CircuitStateOpen:
		return time.Now().After(cb.nextAttemptTime)
	case CircuitStateHalfOpen:
		return true
	default:
		return false
	}
}

// Execute executes an operation through the circuit breaker
func (cb *CircuitBreaker) Execute(operation func() error) error {
	if !cb.CanExecute() {
		return fmt.Errorf("circuit breaker is open")
	}

	err := operation()
	
	cb.mutex.Lock()
	defer cb.mutex.Unlock()
	
	if err != nil {
		cb.onFailure()
		return err
	}
	
	cb.onSuccess()
	return nil
}

// onSuccess handles successful operation
func (cb *CircuitBreaker) onSuccess() {
	cb.failureCount = 0
	cb.lastSuccessTime = time.Now()
	
	if cb.state == CircuitStateHalfOpen {
		cb.setState(CircuitStateClosed)
	}
}

// onFailure handles failed operation
func (cb *CircuitBreaker) onFailure() {
	cb.failureCount++
	cb.lastFailureTime = time.Now()
	
	if cb.state == CircuitStateClosed && cb.failureCount >= cb.config.MaxFailures {
		cb.setState(CircuitStateOpen)
		cb.nextAttemptTime = time.Now().Add(cb.config.Timeout)
	} else if cb.state == CircuitStateHalfOpen {
		cb.setState(CircuitStateOpen)
		cb.nextAttemptTime = time.Now().Add(cb.config.Timeout)
	}
}

// setState changes the circuit breaker state
func (cb *CircuitBreaker) setState(newState CircuitState) {
	if cb.state != newState {
		oldState := cb.state
		cb.state = newState
		
		if cb.onStateChange != nil {
			cb.onStateChange(oldState, newState)
		}
	}
}

// Execute executes a function with bulkhead protection
func (b *Bulkhead) Execute(ctx context.Context, operation func() error) error {
	// Try to acquire semaphore immediately
	select {
	case b.semaphore <- struct{}{}:
		// Got semaphore, execute immediately
		defer func() { <-b.semaphore }()
		
		b.metrics.mutex.Lock()
		b.metrics.ActiveRequests++
		b.metrics.mutex.Unlock()
		
		defer func() {
			b.metrics.mutex.Lock()
			b.metrics.ActiveRequests--
			b.metrics.mutex.Unlock()
		}()
		
		return operation()
	default:
		// Semaphore full, try to queue
		return b.enqueueRequest(ctx, operation)
	}
}

// enqueueRequest queues a request for later execution
func (b *Bulkhead) enqueueRequest(ctx context.Context, operation func() error) error {
	request := &bulkheadRequest{
		execute: operation,
		result:  make(chan error, 1),
		ctx:     ctx,
	}

	// Try to enqueue with timeout
	queueCtx, cancel := context.WithTimeout(ctx, b.config.QueueTimeout)
	defer cancel()

	select {
	case b.queue <- request:
		b.metrics.mutex.Lock()
		b.metrics.QueuedRequests++
		b.metrics.mutex.Unlock()
		
		// Wait for result
		select {
		case err := <-request.result:
			return err
		case <-ctx.Done():
			return ctx.Err()
		}
	case <-queueCtx.Done():
		b.metrics.mutex.Lock()
		b.metrics.RejectedRequests++
		b.metrics.mutex.Unlock()
		
		return fmt.Errorf("bulkhead queue timeout")
	}
}

// processQueue processes queued requests
func (b *Bulkhead) processQueue() {
	for {
		select {
		case request := <-b.queue:
			b.metrics.mutex.Lock()
			b.metrics.QueuedRequests--
			b.metrics.mutex.Unlock()
			
			// Try to acquire semaphore
			select {
			case b.semaphore <- struct{}{}:
				go func(req *bulkheadRequest) {
					defer func() { <-b.semaphore }()
					
					b.metrics.mutex.Lock()
					b.metrics.ActiveRequests++
					b.metrics.mutex.Unlock()
					
					defer func() {
						b.metrics.mutex.Lock()
						b.metrics.ActiveRequests--
						b.metrics.mutex.Unlock()
					}()
					
					// Check if context is still valid
					select {
					case <-req.ctx.Done():
						req.result <- req.ctx.Err()
						return
					default:
					}
					
					// Execute the operation
					err := req.execute()
					
					select {
					case req.result <- err:
					case <-req.ctx.Done():
					}
				}(request)
			case <-request.ctx.Done():
				request.result <- request.ctx.Err()
			case <-b.ctx.Done():
				request.result <- fmt.Errorf("bulkhead shutting down")
			}
		case <-b.ctx.Done():
			return
		}
	}
}

// calculateDelay calculates retry delay with exponential backoff
func (rm *ResilienceManager) calculateDelay(attempt int) time.Duration {
	delay := float64(rm.retryConfig.InitialDelay) * math.Pow(rm.retryConfig.BackoffFactor, float64(attempt-1))
	
	// Apply max delay
	if delay > float64(rm.retryConfig.MaxDelay) {
		delay = float64(rm.retryConfig.MaxDelay)
	}
	
	// Apply jitter if enabled
	if rm.retryConfig.Jitter {
		jitter := delay * 0.1 * (2*math.Round(math.MaxFloat64) - 1) // Random between -10% and +10%
		delay += jitter
	}
	
	return time.Duration(delay)
}

// isRetryableError checks if an error is retryable
func (rm *ResilienceManager) isRetryableError(err error) bool {
	errStr := err.Error()
	
	// Check non-retryable errors first
	for _, nonRetryable := range rm.retryConfig.NonRetryableErrors {
		if contains(errStr, nonRetryable) {
			return false
		}
	}
	
	// Check retryable errors
	for _, retryable := range rm.retryConfig.RetryableErrors {
		if contains(errStr, retryable) {
			return true
		}
	}
	
	// Default behavior based on error type
	return isNetworkError(err) || isTimeoutError(err) || is5xxError(err)
}

// updateMetrics updates resilience metrics
func (rm *ResilienceManager) updateMetrics(err error, duration time.Duration) {
	rm.metrics.mutex.Lock()
	defer rm.metrics.mutex.Unlock()
	
	if err != nil {
		rm.metrics.FailedRequests++
		
		if isTimeoutError(err) {
			rm.metrics.TimeoutErrors++
		}
	} else {
		rm.metrics.SuccessfulRequests++
	}
	
	// Update average response time using exponential moving average
	alpha := 0.1 // Smoothing factor
	durationMs := float64(duration.Nanoseconds()) / 1e6
	
	if rm.metrics.AverageResponseTime == 0 {
		rm.metrics.AverageResponseTime = durationMs
	} else {
		rm.metrics.AverageResponseTime = alpha*durationMs + (1-alpha)*rm.metrics.AverageResponseTime
	}
	
	rm.metrics.CircuitBreakerState = string(rm.circuitBreaker.state)
}

// onCircuitBreakerStateChange handles circuit breaker state changes
func (rm *ResilienceManager) onCircuitBreakerStateChange(from, to CircuitState) {
	rm.logger.Warn("Circuit breaker state changed: %s -> %s", from, to)
	
	if to == CircuitStateOpen {
		rm.metrics.mutex.Lock()
		rm.metrics.CircuitBreakerTrips++
		rm.metrics.mutex.Unlock()
	}
}

// GetMetrics returns current resilience metrics
func (rm *ResilienceManager) GetMetrics() ResilienceMetrics {
	rm.metrics.mutex.RLock()
	defer rm.metrics.mutex.RUnlock()
	
	// Return a copy to avoid race conditions
	return *rm.metrics
}

// GetCircuitBreakerState returns the current circuit breaker state
func (rm *ResilienceManager) GetCircuitBreakerState() CircuitState {
	rm.circuitBreaker.mutex.RLock()
	defer rm.circuitBreaker.mutex.RUnlock()
	
	return rm.circuitBreaker.state
}

// Close gracefully shuts down the resilience manager
func (rm *ResilienceManager) Close() {
	if rm.bulkhead != nil {
		rm.bulkhead.cancel()
	}
	
	rm.logger.Info("Resilience manager shut down")
}

// Default resilience configuration
func DefaultResilienceConfig() ResilienceConfig {
	return ResilienceConfig{
		CircuitBreaker: CircuitBreakerConfig{
			MaxFailures:   5,
			Timeout:       30 * time.Second,
			ResetInterval: 60 * time.Second,
		},
		Retry: RetryConfig{
			MaxAttempts:   3,
			InitialDelay:  1 * time.Second,
			MaxDelay:      30 * time.Second,
			BackoffFactor: 2.0,
			Jitter:        true,
			RetryableErrors: []string{
				"timeout",
				"connection refused",
				"network is unreachable",
				"temporary failure",
				"server error",
			},
			NonRetryableErrors: []string{
				"unauthorized",
				"forbidden",
				"not found",
				"bad request",
				"invalid api key",
			},
		},
		Timeout: TimeoutConfig{
			APITimeout:     30 * time.Second,
			RequestTimeout: 60 * time.Second,
			ContextTimeout: 120 * time.Second,
		},
		Bulkhead: BulkheadConfig{
			MaxConcurrentRequests: 10,
			QueueSize:            50,
			QueueTimeout:         10 * time.Second,
		},
	}
}

// Helper functions

func contains(str, substr string) bool {
	return len(str) >= len(substr) && 
		   (str == substr || 
		    str[:len(substr)] == substr ||
		    str[len(str)-len(substr):] == substr ||
		    indexOf(str, substr) >= 0)
}

func indexOf(str, substr string) int {
	for i := 0; i <= len(str)-len(substr); i++ {
		if str[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}

func isNetworkError(err error) bool {
	errStr := err.Error()
	return contains(errStr, "connection") || 
		   contains(errStr, "network") ||
		   contains(errStr, "dns")
}

func isTimeoutError(err error) bool {
	errStr := err.Error()
	return contains(errStr, "timeout") || 
		   contains(errStr, "deadline exceeded")
}

func is5xxError(err error) bool {
	errStr := err.Error()
	return contains(errStr, "status 5") || 
		   contains(errStr, "server error") ||
		   contains(errStr, "internal error")
}