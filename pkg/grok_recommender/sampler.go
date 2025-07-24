package grok_recommender

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"regexp"
	"strings"
	"time"
)

// TelemetrySampler handles sampling and anonymization of telemetry data
type TelemetrySampler struct {
	maxSampleSize int
	anonymizer    *DataAnonymizer
}

// TelemetrySample represents a sample of telemetry data
type TelemetrySample struct {
	Traces  []TraceSpan         `json:"traces,omitempty"`
	Metrics []MetricDataPoint   `json:"metrics,omitempty"`
	Logs    []LogEntry          `json:"logs,omitempty"`
	Meta    SampleMetadata      `json:"metadata"`
}

// TraceSpan represents a simplified trace span
type TraceSpan struct {
	Name         string            `json:"name"`
	Service      string            `json:"service"`
	Duration     time.Duration     `json:"duration"`
	Status       string            `json:"status"`
	Attributes   map[string]string `json:"attributes"`
	ResourceTags map[string]string `json:"resource_tags"`
}

// MetricDataPoint represents a simplified metric data point
type MetricDataPoint struct {
	Name         string            `json:"name"`
	Value        float64           `json:"value"`
	Type         string            `json:"type"`
	Labels       map[string]string `json:"labels"`
	Timestamp    time.Time         `json:"timestamp"`
	ResourceTags map[string]string `json:"resource_tags"`
}

// LogEntry represents a simplified log entry
type LogEntry struct {
	Level        string            `json:"level"`
	Message      string            `json:"message"`
	Service      string            `json:"service"`
	Timestamp    time.Time         `json:"timestamp"`
	Attributes   map[string]string `json:"attributes"`
	ResourceTags map[string]string `json:"resource_tags"`
}

// SampleMetadata contains metadata about the sample
type SampleMetadata struct {
	SampleSize     int       `json:"sample_size"`
	TimeRange      string    `json:"time_range"`
	Services       []string  `json:"services"`
	SampledAt      time.Time `json:"sampled_at"`
	TotalSpans     int       `json:"total_spans"`
	TotalMetrics   int       `json:"total_metrics"`
	TotalLogs      int       `json:"total_logs"`
}

// DataAnonymizer handles anonymization of sensitive data
type DataAnonymizer struct {
	sensitivePatterns []*regexp.Regexp
	replacements      map[string]string
}

// NewTelemetrySampler creates a new telemetry sampler
func NewTelemetrySampler(maxSampleSize int) *TelemetrySampler {
	return &TelemetrySampler{
		maxSampleSize: maxSampleSize,
		anonymizer:    NewDataAnonymizer(),
	}
}

// NewDataAnonymizer creates a new data anonymizer
func NewDataAnonymizer() *DataAnonymizer {
	// Common sensitive data patterns
	patterns := []string{
		`\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b`,        // Email
		`\b\d{3}-\d{2}-\d{4}\b`,                                       // SSN
		`\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b`,                     // Credit card
		`\b(?:\d{1,3}\.){3}\d{1,3}\b`,                                 // IP address
		`\buser-\d+\b`,                                                // User IDs
		`\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b`, // UUID
		`\b[A-Za-z0-9]{20,}\b`,                                        // Long tokens/keys
	}
	
	compiledPatterns := make([]*regexp.Regexp, len(patterns))
	for i, pattern := range patterns {
		compiledPatterns[i] = regexp.MustCompile(pattern)
	}
	
	return &DataAnonymizer{
		sensitivePatterns: compiledPatterns,
		replacements: map[string]string{
			"email":      "user@example.com",
			"ssn":        "XXX-XX-XXXX",
			"credit":     "XXXX-XXXX-XXXX-XXXX",
			"ip":         "XXX.XXX.XXX.XXX",
			"user_id":    "user-XXXXX",
			"uuid":       "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
			"token":      "REDACTED_TOKEN",
		},
	}
}

// SampleTraces samples and anonymizes trace data
func (s *TelemetrySampler) SampleTraces(traces []TraceSpan) []TraceSpan {
	if len(traces) <= s.maxSampleSize {
		return s.anonymizeTraces(traces)
	}
	
	// Random sampling
	rand.Seed(time.Now().UnixNano())
	sampled := make([]TraceSpan, 0, s.maxSampleSize)
	
	for len(sampled) < s.maxSampleSize && len(traces) > 0 {
		idx := rand.Intn(len(traces))
		sampled = append(sampled, traces[idx])
		traces = append(traces[:idx], traces[idx+1:]...)
	}
	
	return s.anonymizeTraces(sampled)
}

// SampleMetrics samples and anonymizes metric data
func (s *TelemetrySampler) SampleMetrics(metrics []MetricDataPoint) []MetricDataPoint {
	if len(metrics) <= s.maxSampleSize {
		return s.anonymizeMetrics(metrics)
	}
	
	// Random sampling
	rand.Seed(time.Now().UnixNano())
	sampled := make([]MetricDataPoint, 0, s.maxSampleSize)
	
	for len(sampled) < s.maxSampleSize && len(metrics) > 0 {
		idx := rand.Intn(len(metrics))
		sampled = append(sampled, metrics[idx])
		metrics = append(metrics[:idx], metrics[idx+1:]...)
	}
	
	return s.anonymizeMetrics(sampled)
}

// SampleLogs samples and anonymizes log data
func (s *TelemetrySampler) SampleLogs(logs []LogEntry) []LogEntry {
	if len(logs) <= s.maxSampleSize {
		return s.anonymizeLogs(logs)
	}
	
	// Random sampling
	rand.Seed(time.Now().UnixNano())
	sampled := make([]LogEntry, 0, s.maxSampleSize)
	
	for len(sampled) < s.maxSampleSize && len(logs) > 0 {
		idx := rand.Intn(len(logs))
		sampled = append(sampled, logs[idx])
		logs = append(logs[:idx], logs[idx+1:]...)
	}
	
	return s.anonymizeLogs(sampled)
}

// CreateSample creates a complete telemetry sample
func (s *TelemetrySampler) CreateSample(traces []TraceSpan, metrics []MetricDataPoint, logs []LogEntry) *TelemetrySample {
	sampledTraces := s.SampleTraces(traces)
	sampledMetrics := s.SampleMetrics(metrics)
	sampledLogs := s.SampleLogs(logs)
	
	// Extract services
	services := make(map[string]bool)
	for _, trace := range sampledTraces {
		if trace.Service != "" {
			services[trace.Service] = true
		}
	}
	for _, log := range sampledLogs {
		if log.Service != "" {
			services[log.Service] = true
		}
	}
	
	serviceList := make([]string, 0, len(services))
	for service := range services {
		serviceList = append(serviceList, service)
	}
	
	return &TelemetrySample{
		Traces:  sampledTraces,
		Metrics: sampledMetrics,
		Logs:    sampledLogs,
		Meta: SampleMetadata{
			SampleSize:   len(sampledTraces) + len(sampledMetrics) + len(sampledLogs),
			TimeRange:    "last-5m",
			Services:     serviceList,
			SampledAt:    time.Now(),
			TotalSpans:   len(traces),
			TotalMetrics: len(metrics),
			TotalLogs:    len(logs),
		},
	}
}

// anonymizeTraces anonymizes trace data
func (s *TelemetrySampler) anonymizeTraces(traces []TraceSpan) []TraceSpan {
	for i := range traces {
		traces[i].Name = s.anonymizer.AnonymizeString(traces[i].Name)
		traces[i].Service = s.anonymizer.AnonymizeString(traces[i].Service)
		traces[i].Attributes = s.anonymizer.AnonymizeMap(traces[i].Attributes)
		traces[i].ResourceTags = s.anonymizer.AnonymizeMap(traces[i].ResourceTags)
	}
	return traces
}

// anonymizeMetrics anonymizes metric data
func (s *TelemetrySampler) anonymizeMetrics(metrics []MetricDataPoint) []MetricDataPoint {
	for i := range metrics {
		metrics[i].Name = s.anonymizer.AnonymizeString(metrics[i].Name)
		metrics[i].Labels = s.anonymizer.AnonymizeMap(metrics[i].Labels)
		metrics[i].ResourceTags = s.anonymizer.AnonymizeMap(metrics[i].ResourceTags)
	}
	return metrics
}

// anonymizeLogs anonymizes log data
func (s *TelemetrySampler) anonymizeLogs(logs []LogEntry) []LogEntry {
	for i := range logs {
		logs[i].Message = s.anonymizer.AnonymizeString(logs[i].Message)
		logs[i].Service = s.anonymizer.AnonymizeString(logs[i].Service)
		logs[i].Attributes = s.anonymizer.AnonymizeMap(logs[i].Attributes)
		logs[i].ResourceTags = s.anonymizer.AnonymizeMap(logs[i].ResourceTags)
	}
	return logs
}

// AnonymizeString anonymizes a string by replacing sensitive patterns
func (a *DataAnonymizer) AnonymizeString(input string) string {
	result := input
	
	// Replace email addresses
	result = a.sensitivePatterns[0].ReplaceAllString(result, a.replacements["email"])
	
	// Replace SSN
	result = a.sensitivePatterns[1].ReplaceAllString(result, a.replacements["ssn"])
	
	// Replace credit card numbers
	result = a.sensitivePatterns[2].ReplaceAllString(result, a.replacements["credit"])
	
	// Replace IP addresses
	result = a.sensitivePatterns[3].ReplaceAllString(result, a.replacements["ip"])
	
	// Replace user IDs
	result = a.sensitivePatterns[4].ReplaceAllString(result, a.replacements["user_id"])
	
	// Replace UUIDs
	result = a.sensitivePatterns[5].ReplaceAllString(result, a.replacements["uuid"])
	
	// Replace long tokens/keys
	result = a.sensitivePatterns[6].ReplaceAllString(result, a.replacements["token"])
	
	return result
}

// AnonymizeMap anonymizes a map of string key-value pairs
func (a *DataAnonymizer) AnonymizeMap(input map[string]string) map[string]string {
	result := make(map[string]string)
	for k, v := range input {
		result[k] = a.AnonymizeString(v)
	}
	return result
}

// ToJSON converts the sample to JSON string
func (s *TelemetrySample) ToJSON() (string, error) {
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal sample to JSON: %w", err)
	}
	return string(data), nil
}

// FromJSON creates a sample from JSON string
func FromJSON(jsonData string) (*TelemetrySample, error) {
	var sample TelemetrySample
	if err := json.Unmarshal([]byte(jsonData), &sample); err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON to sample: %w", err)
	}
	return &sample, nil
}