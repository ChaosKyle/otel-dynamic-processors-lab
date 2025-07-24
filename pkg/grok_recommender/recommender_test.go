package grok_recommender

import (
	"context"
	"testing"
	"time"
)

func TestNewRecommender(t *testing.T) {
	config := &RecommenderConfig{
		APIKey:            "test-key",
		MaxSampleSize:     100,
		SamplingInterval:  time.Minute,
		CacheExpiration:   time.Hour,
		RateLimitRPM:      60,
		EnableCache:       true,
		EnableRateLimit:   true,
		FallbackToStatic:  true,
		LogLevel:          "info",
	}
	
	recommender, err := NewRecommender(config)
	if err != nil {
		t.Fatalf("Failed to create recommender: %v", err)
	}
	
	if recommender == nil {
		t.Fatal("Recommender is nil")
	}
	
	if recommender.config.APIKey != "test-key" {
		t.Errorf("Expected API key 'test-key', got %s", recommender.config.APIKey)
	}
}

func TestNewRecommenderWithoutAPIKey(t *testing.T) {
	config := &RecommenderConfig{
		MaxSampleSize: 100,
	}
	
	_, err := NewRecommender(config)
	if err == nil {
		t.Fatal("Expected error for missing API key")
	}
}

func TestTelemetrySampler(t *testing.T) {
	sampler := NewTelemetrySampler(10)
	
	// Test with traces
	traces := []TraceSpan{
		{Name: "test-span-1", Service: "test-service", Duration: time.Millisecond * 100},
		{Name: "test-span-2", Service: "test-service", Duration: time.Millisecond * 200},
	}
	
	sampledTraces := sampler.SampleTraces(traces)
	if len(sampledTraces) != 2 {
		t.Errorf("Expected 2 sampled traces, got %d", len(sampledTraces))
	}
	
	// Test with metrics
	metrics := []MetricDataPoint{
		{Name: "test-metric-1", Value: 123.45, Type: "gauge"},
		{Name: "test-metric-2", Value: 678.90, Type: "counter"},
	}
	
	sampledMetrics := sampler.SampleMetrics(metrics)
	if len(sampledMetrics) != 2 {
		t.Errorf("Expected 2 sampled metrics, got %d", len(sampledMetrics))
	}
}

func TestDataAnonymizer(t *testing.T) {
	anonymizer := NewDataAnonymizer()
	
	// Test email anonymization
	input := "User email is john.doe@example.com"
	output := anonymizer.AnonymizeString(input)
	if output == input {
		t.Error("Email should be anonymized")
	}
	
	// Test IP anonymization
	input = "Server IP is 192.168.1.1"
	output = anonymizer.AnonymizeString(input)
	if output == input {
		t.Error("IP should be anonymized")
	}
}

func TestRecommendationParser(t *testing.T) {
	parser := NewRecommendationParser()
	
	// Mock Grok response
	mockResponse := &GrokResponse{
		Choices: []Choice{
			{
				Message: Message{
					Content: `
1. SIGNALS TO DROP:
   - Drop debug level logs as they create excessive noise
   - Remove metrics with high cardinality labels

2. LABEL POLICY VIOLATIONS:
   - Spans missing environment label should be dropped
   - Metrics without service label are non-compliant

3. OTEL FILTER RULES:
   traces:
     span:
       - 'attributes["level"] == "DEBUG"'
       - 'resource.attributes["environment"] == nil'
   metrics:
     metric:
       - 'labels["cardinality"] > 1000'

4. RATIONALE:
   - Debug logs consume 40% of storage with minimal value
   - Environment labels are required for proper data organization
					`,
				},
			},
		},
	}
	
	recommendations, err := parser.ParseRecommendations(mockResponse)
	if err != nil {
		t.Fatalf("Failed to parse recommendations: %v", err)
	}
	
	if len(recommendations.Recommendations) == 0 {
		t.Error("Expected recommendations to be parsed")
	}
	
	// Test YAML generation
	yamlConfig := parser.GenerateYAMLConfig(recommendations.Recommendations)
	if yamlConfig == "" {
		t.Error("Expected YAML config to be generated")
	}
}

func TestRateLimiter(t *testing.T) {
	// Create a rate limiter with 2 requests per minute
	rateLimiter := NewRateLimiter(2)
	
	ctx := context.Background()
	
	// First request should succeed immediately
	start := time.Now()
	err := rateLimiter.Wait(ctx)
	if err != nil {
		t.Fatalf("First request failed: %v", err)
	}
	
	elapsed := time.Since(start)
	if elapsed > time.Millisecond*100 {
		t.Errorf("First request took too long: %v", elapsed)
	}
	
	// Second request should also succeed
	err = rateLimiter.Wait(ctx)
	if err != nil {
		t.Fatalf("Second request failed: %v", err)
	}
}

func TestRecommendationCache(t *testing.T) {
	config := &RecommenderConfig{
		APIKey:          "test-key",
		MaxSampleSize:   100,
		CacheExpiration: time.Hour,
		EnableCache:     true,
	}
	
	recommender, err := NewRecommender(config)
	if err != nil {
		t.Fatalf("Failed to create recommender: %v", err)
	}
	
	sample := &TelemetrySample{
		Meta: SampleMetadata{
			TotalSpans:   10,
			TotalMetrics: 5,
			TotalLogs:    3,
		},
	}
	
	// Should return nil for uncached sample
	cached := recommender.getCachedRecommendations(sample)
	if cached != nil {
		t.Error("Expected nil for uncached sample")
	}
	
	// Cache a recommendation
	recommendations := &ParsedRecommendations{
		Recommendations: []Recommendation{
			{
				ID:          "test-1",
				Type:        RecommendationTypeDropSignal,
				Priority:    PriorityMedium,
				Description: "Test recommendation",
			},
		},
	}
	
	recommender.cacheRecommendations(sample, recommendations)
	
	// Should return cached recommendation
	cached = recommender.getCachedRecommendations(sample)
	if cached == nil {
		t.Error("Expected cached recommendation")
	}
	
	if len(cached.Recommendations) != 1 {
		t.Errorf("Expected 1 cached recommendation, got %d", len(cached.Recommendations))
	}
}

func TestStaticRecommendations(t *testing.T) {
	config := &RecommenderConfig{
		APIKey:           "test-key",
		MaxSampleSize:    100,
		FallbackToStatic: true,
	}
	
	recommender, err := NewRecommender(config)
	if err != nil {
		t.Fatalf("Failed to create recommender: %v", err)
	}
	
	sample := &TelemetrySample{
		Meta: SampleMetadata{
			TotalSpans:   10,
			TotalMetrics: 5,
			TotalLogs:    3,
		},
	}
	
	policies := []LabelPolicy{
		{
			Name:           "environment-required",
			RequiredLabels: []string{"environment"},
			Enforcement:    "drop",
		},
	}
	
	recommendations := recommender.generateStaticRecommendations(sample, policies)
	
	if len(recommendations.Recommendations) == 0 {
		t.Error("Expected static recommendations")
	}
	
	if recommendations.Summary.TotalRecommendations == 0 {
		t.Error("Expected summary to have total recommendations")
	}
}

func TestCreateSample(t *testing.T) {
	sampler := NewTelemetrySampler(100)
	
	traces := []TraceSpan{
		{Name: "test-span", Service: "test-service", Duration: time.Millisecond * 100},
	}
	
	metrics := []MetricDataPoint{
		{Name: "test-metric", Value: 123.45, Type: "gauge"},
	}
	
	logs := []LogEntry{
		{Level: "INFO", Message: "test message", Service: "test-service"},
	}
	
	sample := sampler.CreateSample(traces, metrics, logs)
	
	if sample == nil {
		t.Fatal("Sample should not be nil")
	}
	
	if len(sample.Traces) != 1 {
		t.Errorf("Expected 1 trace, got %d", len(sample.Traces))
	}
	
	if len(sample.Metrics) != 1 {
		t.Errorf("Expected 1 metric, got %d", len(sample.Metrics))
	}
	
	if len(sample.Logs) != 1 {
		t.Errorf("Expected 1 log, got %d", len(sample.Logs))
	}
	
	if sample.Meta.TotalSpans != 1 {
		t.Errorf("Expected total spans 1, got %d", sample.Meta.TotalSpans)
	}
	
	if len(sample.Meta.Services) != 1 {
		t.Errorf("Expected 1 service, got %d", len(sample.Meta.Services))
	}
	
	if sample.Meta.Services[0] != "test-service" {
		t.Errorf("Expected service 'test-service', got %s", sample.Meta.Services[0])
	}
}

func TestSampleToJSON(t *testing.T) {
	sample := &TelemetrySample{
		Traces: []TraceSpan{
			{Name: "test-span", Service: "test-service", Duration: time.Millisecond * 100},
		},
		Meta: SampleMetadata{
			TotalSpans: 1,
			Services:   []string{"test-service"},
		},
	}
	
	jsonData, err := sample.ToJSON()
	if err != nil {
		t.Fatalf("Failed to convert sample to JSON: %v", err)
	}
	
	if jsonData == "" {
		t.Error("JSON data should not be empty")
	}
	
	// Test round-trip
	parsedSample, err := FromJSON(jsonData)
	if err != nil {
		t.Fatalf("Failed to parse JSON: %v", err)
	}
	
	if len(parsedSample.Traces) != 1 {
		t.Errorf("Expected 1 trace after parsing, got %d", len(parsedSample.Traces))
	}
	
	if parsedSample.Meta.TotalSpans != 1 {
		t.Errorf("Expected total spans 1 after parsing, got %d", parsedSample.Meta.TotalSpans)
	}
}