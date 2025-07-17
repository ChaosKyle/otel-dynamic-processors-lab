package grok_recommender

import (
	"context"
	"fmt"
	"log"
	"os"
	"sync"
	"time"
)

// Recommender orchestrates the entire recommendation process
type Recommender struct {
	client      *GrokClient
	sampler     *TelemetrySampler
	parser      *RecommendationParser
	config      *RecommenderConfig
	cache       *RecommendationCache
	rateLimiter *RateLimiter
	logger      *log.Logger
}

// RecommenderConfig contains configuration for the recommender
type RecommenderConfig struct {
	APIKey            string        `json:"api_key"`
	MaxSampleSize     int           `json:"max_sample_size"`
	SamplingInterval  time.Duration `json:"sampling_interval"`
	CacheExpiration   time.Duration `json:"cache_expiration"`
	RateLimitRPM      int           `json:"rate_limit_rpm"`
	EnableCache       bool          `json:"enable_cache"`
	EnableRateLimit   bool          `json:"enable_rate_limit"`
	FallbackToStatic  bool          `json:"fallback_to_static"`
	LogLevel          string        `json:"log_level"`
	PolicyFile        string        `json:"policy_file"`
}

// RecommendationCache provides caching for recommendations
type RecommendationCache struct {
	cache      map[string]*CacheEntry
	mutex      sync.RWMutex
	expiration time.Duration
}

// CacheEntry represents a cached recommendation
type CacheEntry struct {
	Recommendations *ParsedRecommendations
	CreatedAt       time.Time
}

// RateLimiter provides rate limiting for API calls
type RateLimiter struct {
	tokens      chan struct{}
	refillRate  time.Duration
	capacity    int
	lastRefill  time.Time
	mutex       sync.Mutex
}

// LabelPolicy represents a label policy configuration
type LabelPolicy struct {
	Name            string   `json:"name"`
	RequiredLabels  []string `json:"required_labels"`
	ForbiddenLabels []string `json:"forbidden_labels"`
	LabelPatterns   []string `json:"label_patterns"`
	Enforcement     string   `json:"enforcement"` // "drop", "warn", "fix"
}

// NewRecommender creates a new recommender instance
func NewRecommender(config *RecommenderConfig) (*Recommender, error) {
	// Validate configuration
	if config.APIKey == "" {
		return nil, fmt.Errorf("API key is required")
	}
	
	client := NewGrokClient(config.APIKey)
	sampler := NewTelemetrySampler(config.MaxSampleSize)
	parser := NewRecommendationParser()
	
	cache := &RecommendationCache{
		cache:      make(map[string]*CacheEntry),
		expiration: config.CacheExpiration,
	}
	
	rateLimiter := NewRateLimiter(config.RateLimitRPM)
	
	logger := log.New(os.Stdout, "[GROK-RECOMMENDER] ", log.LstdFlags)
	
	return &Recommender{
		client:      client,
		sampler:     sampler,
		parser:      parser,
		config:      config,
		cache:       cache,
		rateLimiter: rateLimiter,
		logger:      logger,
	}, nil
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(rpm int) *RateLimiter {
	capacity := rpm
	tokens := make(chan struct{}, capacity)
	
	// Fill initial tokens
	for i := 0; i < capacity; i++ {
		tokens <- struct{}{}
	}
	
	rl := &RateLimiter{
		tokens:     tokens,
		refillRate: time.Minute / time.Duration(rpm),
		capacity:   capacity,
		lastRefill: time.Now(),
	}
	
	// Start refill goroutine
	go rl.refillTokens()
	
	return rl
}

// refillTokens refills tokens at the specified rate
func (rl *RateLimiter) refillTokens() {
	ticker := time.NewTicker(rl.refillRate)
	defer ticker.Stop()
	
	for range ticker.C {
		select {
		case rl.tokens <- struct{}{}:
			// Token added
		default:
			// Channel full, skip
		}
	}
}

// Wait waits for a token to become available
func (rl *RateLimiter) Wait(ctx context.Context) error {
	select {
	case <-rl.tokens:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// GenerateRecommendations generates recommendations for the given telemetry data
func (r *Recommender) GenerateRecommendations(ctx context.Context, sample *TelemetrySample, policies []LabelPolicy) (*ParsedRecommendations, error) {
	// Check cache first
	if r.config.EnableCache {
		if cached := r.getCachedRecommendations(sample); cached != nil {
			r.logger.Printf("Returning cached recommendations for sample")
			return cached, nil
		}
	}
	
	// Rate limiting
	if r.config.EnableRateLimit {
		if err := r.rateLimiter.Wait(ctx); err != nil {
			return nil, fmt.Errorf("rate limit exceeded: %w", err)
		}
	}
	
	// Convert sample to JSON
	jsonData, err := sample.ToJSON()
	if err != nil {
		return nil, fmt.Errorf("failed to convert sample to JSON: %w", err)
	}
	
	// Convert policies to strings
	policyStrings := r.policiesToStrings(policies)
	
	// Call Grok API
	r.logger.Printf("Calling Grok API for recommendations")
	response, err := r.client.GenerateRecommendations(ctx, jsonData, policyStrings)
	if err != nil {
		if r.config.FallbackToStatic {
			r.logger.Printf("Grok API failed, falling back to static recommendations: %v", err)
			return r.generateStaticRecommendations(sample, policies), nil
		}
		return nil, fmt.Errorf("failed to get recommendations from Grok: %w", err)
	}
	
	// Parse recommendations
	recommendations, err := r.parser.ParseRecommendations(response)
	if err != nil {
		return nil, fmt.Errorf("failed to parse recommendations: %w", err)
	}
	
	// Cache recommendations
	if r.config.EnableCache {
		r.cacheRecommendations(sample, recommendations)
	}
	
	r.logger.Printf("Generated %d recommendations", len(recommendations.Recommendations))
	
	return recommendations, nil
}

// getCachedRecommendations retrieves cached recommendations
func (r *Recommender) getCachedRecommendations(sample *TelemetrySample) *ParsedRecommendations {
	r.cache.mutex.RLock()
	defer r.cache.mutex.RUnlock()
	
	key := r.generateCacheKey(sample)
	entry, exists := r.cache.cache[key]
	
	if !exists {
		return nil
	}
	
	// Check if cache entry is expired
	if time.Since(entry.CreatedAt) > r.cache.expiration {
		delete(r.cache.cache, key)
		return nil
	}
	
	return entry.Recommendations
}

// cacheRecommendations caches recommendations
func (r *Recommender) cacheRecommendations(sample *TelemetrySample, recommendations *ParsedRecommendations) {
	r.cache.mutex.Lock()
	defer r.cache.mutex.Unlock()
	
	key := r.generateCacheKey(sample)
	r.cache.cache[key] = &CacheEntry{
		Recommendations: recommendations,
		CreatedAt:       time.Now(),
	}
}

// generateCacheKey generates a cache key for a sample
func (r *Recommender) generateCacheKey(sample *TelemetrySample) string {
	return fmt.Sprintf("sample-%d-%d-%d", 
		sample.Meta.TotalSpans, 
		sample.Meta.TotalMetrics, 
		sample.Meta.TotalLogs)
}

// policiesToStrings converts policies to string representations
func (r *Recommender) policiesToStrings(policies []LabelPolicy) []string {
	var strings []string
	
	for _, policy := range policies {
		policyStr := fmt.Sprintf("Policy '%s': ", policy.Name)
		
		if len(policy.RequiredLabels) > 0 {
			policyStr += fmt.Sprintf("Required labels: %v. ", policy.RequiredLabels)
		}
		
		if len(policy.ForbiddenLabels) > 0 {
			policyStr += fmt.Sprintf("Forbidden labels: %v. ", policy.ForbiddenLabels)
		}
		
		if len(policy.LabelPatterns) > 0 {
			policyStr += fmt.Sprintf("Label patterns: %v. ", policy.LabelPatterns)
		}
		
		policyStr += fmt.Sprintf("Enforcement: %s", policy.Enforcement)
		
		strings = append(strings, policyStr)
	}
	
	return strings
}

// generateStaticRecommendations generates fallback static recommendations
func (r *Recommender) generateStaticRecommendations(sample *TelemetrySample, policies []LabelPolicy) *ParsedRecommendations {
	var recommendations []Recommendation
	
	// Static recommendation 1: Drop debug logs
	recommendations = append(recommendations, Recommendation{
		ID:          "static-1",
		Type:        RecommendationTypeDropSignal,
		Priority:    PriorityMedium,
		Description: "Drop debug level logs to reduce noise",
		Rationale:   "Debug logs are typically high volume and low value in production",
		FilterRules: []FilterRule{
			{
				Name:        "drop-debug-logs",
				Type:        SignalTypeLog,
				Condition:   `attributes["level"] == "DEBUG"`,
				Action:      "drop",
				Description: "Drop debug level logs",
			},
		},
		CreatedAt: time.Now(),
	})
	
	// Static recommendation 2: Enforce environment labels
	recommendations = append(recommendations, Recommendation{
		ID:          "static-2",
		Type:        RecommendationTypeLabelPolicy,
		Priority:    PriorityHigh,
		Description: "Enforce environment label presence",
		Rationale:   "Environment labels are required for proper data organization",
		FilterRules: []FilterRule{
			{
				Name:        "require-env-label",
				Type:        SignalTypeTrace,
				Condition:   `resource.attributes["environment"] == nil`,
				Action:      "drop",
				Description: "Drop spans without environment label",
			},
		},
		CreatedAt: time.Now(),
	})
	
	summary := Summary{
		TotalRecommendations: len(recommendations),
		ByType: map[RecommendationType]int{
			RecommendationTypeDropSignal:  1,
			RecommendationTypeLabelPolicy: 1,
		},
		ByPriority: map[Priority]int{
			PriorityHigh:   1,
			PriorityMedium: 1,
		},
		EstimatedSavings: "10-20%",
	}
	
	return &ParsedRecommendations{
		Recommendations: recommendations,
		Summary:         summary,
		GeneratedAt:     time.Now(),
	}
}

// ValidateConnection validates the connection to Grok API
func (r *Recommender) ValidateConnection(ctx context.Context) error {
	return r.client.ValidateAPIKey(ctx)
}

// GetConfig returns the current configuration
func (r *Recommender) GetConfig() *RecommenderConfig {
	return r.config
}

// UpdateConfig updates the configuration
func (r *Recommender) UpdateConfig(config *RecommenderConfig) error {
	r.config = config
	
	// Update client if API key changed
	if config.APIKey != r.client.apiKey {
		r.client = NewGrokClient(config.APIKey)
	}
	
	// Update sampler if max sample size changed
	if config.MaxSampleSize != r.sampler.maxSampleSize {
		r.sampler = NewTelemetrySampler(config.MaxSampleSize)
	}
	
	// Update cache expiration
	r.cache.expiration = config.CacheExpiration
	
	return nil
}

// ClearCache clears the recommendation cache
func (r *Recommender) ClearCache() {
	r.cache.mutex.Lock()
	defer r.cache.mutex.Unlock()
	
	r.cache.cache = make(map[string]*CacheEntry)
	r.logger.Printf("Recommendation cache cleared")
}

// GetCacheStats returns cache statistics
func (r *Recommender) GetCacheStats() map[string]interface{} {
	r.cache.mutex.RLock()
	defer r.cache.mutex.RUnlock()
	
	return map[string]interface{}{
		"cache_size":    len(r.cache.cache),
		"cache_enabled": r.config.EnableCache,
		"expiration":    r.cache.expiration.String(),
	}
}