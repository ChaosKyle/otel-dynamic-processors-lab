package grok_recommender

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
	"crypto/md5"
	"encoding/hex"
)

// RecommendationParser parses Grok API responses into structured recommendations
type RecommendationParser struct {
	patterns map[string]*regexp.Regexp
	logger   Logger
}

// Logger interface for structured logging
type Logger interface {
	Info(msg string, args ...interface{})
	Warn(msg string, args ...interface{})
	Error(msg string, args ...interface{})
	Debug(msg string, args ...interface{})
}

// NewRecommendationParser creates a new recommendation parser
func NewRecommendationParser() *RecommendationParser {
	parser := &RecommendationParser{
		patterns: make(map[string]*regexp.Regexp),
		logger:   &defaultLogger{},
	}
	
	parser.initializePatterns()
	return parser
}

// initializePatterns initializes regex patterns for parsing
func (rp *RecommendationParser) initializePatterns() {
	rp.patterns["signals_to_drop"] = regexp.MustCompile(`(?i)1\.\s*SIGNALS\s*TO\s*DROP:\s*(.*?)(?=2\.|3\.|4\.|$)`)
	rp.patterns["label_policy_violations"] = regexp.MustCompile(`(?i)2\.\s*LABEL\s*POLICY\s*VIOLATIONS:\s*(.*?)(?=3\.|4\.|1\.|$)`)
	rp.patterns["otel_filter_rules"] = regexp.MustCompile(`(?i)3\.\s*OTEL\s*FILTER\s*RULES:\s*(.*?)(?=4\.|1\.|2\.|$)`)
	rp.patterns["rationale"] = regexp.MustCompile(`(?i)4\.\s*RATIONALE:\s*(.*?)$`)
	
	// Filter rule patterns
	rp.patterns["trace_filter"] = regexp.MustCompile(`traces:\s*span:\s*((?:\s*-\s*'[^']*'\s*)*)`)
	rp.patterns["metric_filter"] = regexp.MustCompile(`metrics:\s*metric:\s*((?:\s*-\s*'[^']*'\s*)*)`)
	rp.patterns["log_filter"] = regexp.MustCompile(`logs:\s*log:\s*((?:\s*-\s*'[^']*'\s*)*)`)
	
	// Individual filter conditions
	rp.patterns["filter_condition"] = regexp.MustCompile(`-\s*'([^']*)'`)
	
	// Performance/impact patterns
	rp.patterns["percentage"] = regexp.MustCompile(`(\d+(?:\.\d+)?)\s*%`)
	rp.patterns["cost_reduction"] = regexp.MustCompile(`(?i)cost.*?(\d+(?:\.\d+)?)\s*%`)
	rp.patterns["volume_reduction"] = regexp.MustCompile(`(?i)(?:volume|data).*?(\d+(?:\.\d+)?)\s*%`)
}

// ParseRecommendations parses a Grok API response into structured recommendations
func (rp *RecommendationParser) ParseRecommendations(response *GrokResponse) (*ParsedRecommendations, error) {
	if response == nil || len(response.Choices) == 0 {
		return nil, fmt.Errorf("empty or invalid Grok response")
	}
	
	content := response.Choices[0].Message.Content
	rp.logger.Debug("Parsing Grok response content: %s", content)
	
	recommendations, err := rp.parseContent(content)
	if err != nil {
		return nil, fmt.Errorf("failed to parse content: %w", err)
	}
	
	summary := rp.generateSummary(recommendations)
	
	return &ParsedRecommendations{
		Recommendations: recommendations,
		Summary:         summary,
		GeneratedAt:     time.Now(),
		Source:          "grok-ai",
		Version:         "1.0.0",
	}, nil
}

// parseContent parses the main content of the Grok response
func (rp *RecommendationParser) parseContent(content string) ([]Recommendation, error) {
	var recommendations []Recommendation
	
	// Parse signals to drop
	dropSignals := rp.parseSignalsToDrop(content)
	recommendations = append(recommendations, dropSignals...)
	
	// Parse label policy violations
	policyViolations := rp.parseLabelPolicyViolations(content)
	recommendations = append(recommendations, policyViolations...)
	
	// Parse filter rules
	filterRecs := rp.parseFilterRules(content)
	recommendations = append(recommendations, filterRecs...)
	
	// Parse rationale and apply to all recommendations
	rationale := rp.parseRationale(content)
	for i := range recommendations {
		if recommendations[i].Rationale == "" {
			recommendations[i].Rationale = rationale
		}
		
		// Set creation time
		recommendations[i].CreatedAt = time.Now()
		recommendations[i].ExpiresAt = time.Now().Add(24 * time.Hour) // 24 hour expiry
		
		// Generate ID if not set
		if recommendations[i].ID == "" {
			recommendations[i].ID = rp.generateRecommendationID(recommendations[i])
		}
		
		// Parse impact if not set
		if recommendations[i].Impact == (Impact{}) {
			recommendations[i].Impact = rp.parseImpact(content, recommendations[i])
		}
	}
	
	return recommendations, nil
}

// parseSignalsToDrop parses signals to drop recommendations
func (rp *RecommendationParser) parseSignalsToDrop(content string) []Recommendation {
	var recommendations []Recommendation
	
	match := rp.patterns["signals_to_drop"].FindStringSubmatch(content)
	if len(match) < 2 {
		rp.logger.Debug("No 'signals to drop' section found")
		return recommendations
	}
	
	signalsSection := match[1]
	lines := strings.Split(signalsSection, "\n")
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "-") {
			continue
		}
		
		description := strings.TrimSpace(strings.TrimPrefix(line, "-"))
		if description == "" {
			continue
		}
		
		recommendation := Recommendation{
			Type:        RecommendationTypeDropSignal,
			Priority:    rp.determinePriority(description),
			Description: description,
			FilterRules: []FilterRule{},
		}
		
		// Generate filter rules based on description
		filterRules := rp.generateFilterRulesFromDescription(description, SignalTypeTrace)
		recommendation.FilterRules = append(recommendation.FilterRules, filterRules...)
		
		recommendations = append(recommendations, recommendation)
	}
	
	return recommendations
}

// parseLabelPolicyViolations parses label policy violation recommendations
func (rp *RecommendationParser) parseLabelPolicyViolations(content string) []Recommendation {
	var recommendations []Recommendation
	
	match := rp.patterns["label_policy_violations"].FindStringSubmatch(content)
	if len(match) < 2 {
		rp.logger.Debug("No 'label policy violations' section found")
		return recommendations
	}
	
	policySection := match[1]
	lines := strings.Split(policySection, "\n")
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "-") {
			continue
		}
		
		description := strings.TrimSpace(strings.TrimPrefix(line, "-"))
		if description == "" {
			continue
		}
		
		recommendation := Recommendation{
			Type:        RecommendationTypeLabelPolicy,
			Priority:    PriorityHigh, // Policy violations are always high priority
			Description: description,
			FilterRules: []FilterRule{},
		}
		
		// Generate filter rules for policy violations
		filterRules := rp.generatePolicyFilterRules(description)
		recommendation.FilterRules = append(recommendation.FilterRules, filterRules...)
		
		recommendations = append(recommendations, recommendation)
	}
	
	return recommendations
}

// parseFilterRules parses OTEL filter rules from the response
func (rp *RecommendationParser) parseFilterRules(content string) []Recommendation {
	var recommendations []Recommendation
	
	match := rp.patterns["otel_filter_rules"].FindStringSubmatch(content)
	if len(match) < 2 {
		rp.logger.Debug("No 'OTEL filter rules' section found")
		return recommendations
	}
	
	rulesSection := match[1]
	
	// Parse trace filters
	traceFilters := rp.parseTraceFilters(rulesSection)
	if len(traceFilters) > 0 {
		recommendation := Recommendation{
			Type:        RecommendationTypeOptimization,
			Priority:    PriorityMedium,
			Description: "Apply trace filtering rules",
			FilterRules: traceFilters,
		}
		recommendations = append(recommendations, recommendation)
	}
	
	// Parse metric filters
	metricFilters := rp.parseMetricFilters(rulesSection)
	if len(metricFilters) > 0 {
		recommendation := Recommendation{
			Type:        RecommendationTypeOptimization,
			Priority:    PriorityMedium,
			Description: "Apply metric filtering rules",
			FilterRules: metricFilters,
		}
		recommendations = append(recommendations, recommendation)
	}
	
	// Parse log filters
	logFilters := rp.parseLogFilters(rulesSection)
	if len(logFilters) > 0 {
		recommendation := Recommendation{
			Type:        RecommendationTypeOptimization,
			Priority:    PriorityMedium,
			Description: "Apply log filtering rules",
			FilterRules: logFilters,
		}
		recommendations = append(recommendations, recommendation)
	}
	
	return recommendations
}

// parseTraceFilters parses trace filter rules
func (rp *RecommendationParser) parseTraceFilters(content string) []FilterRule {
	var filterRules []FilterRule
	
	match := rp.patterns["trace_filter"].FindStringSubmatch(content)
	if len(match) < 2 {
		return filterRules
	}
	
	conditions := rp.patterns["filter_condition"].FindAllStringSubmatch(match[1], -1)
	for i, conditionMatch := range conditions {
		if len(conditionMatch) < 2 {
			continue
		}
		
		condition := conditionMatch[1]
		filterRule := FilterRule{
			Name:        fmt.Sprintf("trace-filter-%d", i+1),
			Type:        SignalTypeTrace,
			Condition:   condition,
			Action:      "drop",
			Description: fmt.Sprintf("Drop traces matching: %s", condition),
			Priority:    i + 1,
		}
		
		filterRules = append(filterRules, filterRule)
	}
	
	return filterRules
}

// parseMetricFilters parses metric filter rules
func (rp *RecommendationParser) parseMetricFilters(content string) []FilterRule {
	var filterRules []FilterRule
	
	match := rp.patterns["metric_filter"].FindStringSubmatch(content)
	if len(match) < 2 {
		return filterRules
	}
	
	conditions := rp.patterns["filter_condition"].FindAllStringSubmatch(match[1], -1)
	for i, conditionMatch := range conditions {
		if len(conditionMatch) < 2 {
			continue
		}
		
		condition := conditionMatch[1]
		filterRule := FilterRule{
			Name:        fmt.Sprintf("metric-filter-%d", i+1),
			Type:        SignalTypeMetric,
			Condition:   condition,
			Action:      "drop",
			Description: fmt.Sprintf("Drop metrics matching: %s", condition),
			Priority:    i + 1,
		}
		
		filterRules = append(filterRules, filterRule)
	}
	
	return filterRules
}

// parseLogFilters parses log filter rules
func (rp *RecommendationParser) parseLogFilters(content string) []FilterRule {
	var filterRules []FilterRule
	
	match := rp.patterns["log_filter"].FindStringSubmatch(content)
	if len(match) < 2 {
		return filterRules
	}
	
	conditions := rp.patterns["filter_condition"].FindAllStringSubmatch(match[1], -1)
	for i, conditionMatch := range conditions {
		if len(conditionMatch) < 2 {
			continue
		}
		
		condition := conditionMatch[1]
		filterRule := FilterRule{
			Name:        fmt.Sprintf("log-filter-%d", i+1),
			Type:        SignalTypeLog,
			Condition:   condition,
			Action:      "drop",
			Description: fmt.Sprintf("Drop logs matching: %s", condition),
			Priority:    i + 1,
		}
		
		filterRules = append(filterRules, filterRule)
	}
	
	return filterRules
}

// parseRationale parses the rationale section
func (rp *RecommendationParser) parseRationale(content string) string {
	match := rp.patterns["rationale"].FindStringSubmatch(content)
	if len(match) < 2 {
		return "AI-generated recommendation based on telemetry analysis"
	}
	
	rationale := strings.TrimSpace(match[1])
	// Clean up the rationale text
	rationale = strings.ReplaceAll(rationale, "\n", " ")
	rationale = regexp.MustCompile(`\s+`).ReplaceAllString(rationale, " ")
	
	return rationale
}

// parseImpact parses impact information from the content
func (rp *RecommendationParser) parseImpact(content string, recommendation Recommendation) Impact {
	impact := Impact{
		ConfidenceScore: 0.8, // Default confidence
	}
	
	// Look for percentage mentions in rationale or content
	if costMatch := rp.patterns["cost_reduction"].FindStringSubmatch(content); len(costMatch) > 1 {
		impact.CostSavings = costMatch[1] + "%"
	}
	
	if volumeMatch := rp.patterns["volume_reduction"].FindStringSubmatch(content); len(volumeMatch) > 1 {
		impact.DataVolumeReduction = volumeMatch[1] + "%"
	}
	
	// Default estimates based on recommendation type
	if impact.DataVolumeReduction == "" {
		switch recommendation.Type {
		case RecommendationTypeDropSignal:
			impact.DataVolumeReduction = "20-40%"
		case RecommendationTypeLabelPolicy:
			impact.DataVolumeReduction = "5-15%"
		case RecommendationTypeOptimization:
			impact.DataVolumeReduction = "10-25%"
		default:
			impact.DataVolumeReduction = "5-20%"
		}
	}
	
	if impact.CostSavings == "" {
		impact.CostSavings = impact.DataVolumeReduction // Assume cost savings match data reduction
	}
	
	impact.PerformanceGain = "Low to Medium"
	
	return impact
}

// Helper methods

// determinePriority determines priority based on description content
func (rp *RecommendationParser) determinePriority(description string) Priority {
	lowerDesc := strings.ToLower(description)
	
	// High priority keywords
	highPriorityWords := []string{"debug", "error", "critical", "security", "sensitive", "production"}
	for _, word := range highPriorityWords {
		if strings.Contains(lowerDesc, word) {
			return PriorityHigh
		}
	}
	
	// Medium priority keywords
	mediumPriorityWords := []string{"noise", "volume", "cost", "performance"}
	for _, word := range mediumPriorityWords {
		if strings.Contains(lowerDesc, word) {
			return PriorityMedium
		}
	}
	
	return PriorityLow
}

// generateFilterRulesFromDescription creates filter rules based on description
func (rp *RecommendationParser) generateFilterRulesFromDescription(description string, signalType SignalType) []FilterRule {
	var rules []FilterRule
	
	lowerDesc := strings.ToLower(description)
	
	// Common patterns
	if strings.Contains(lowerDesc, "debug") {
		rule := FilterRule{
			Name:        "drop-debug-signals",
			Type:        signalType,
			Condition:   `attributes["level"] == "DEBUG"`,
			Action:      "drop",
			Description: "Drop debug level signals",
			Priority:    1,
		}
		rules = append(rules, rule)
	}
	
	if strings.Contains(lowerDesc, "development") || strings.Contains(lowerDesc, "dev") {
		rule := FilterRule{
			Name:        "drop-dev-signals",
			Type:        signalType,
			Condition:   `resource.attributes["environment"] == "dev"`,
			Action:      "drop",
			Description: "Drop development environment signals",
			Priority:    1,
		}
		rules = append(rules, rule)
	}
	
	if strings.Contains(lowerDesc, "health") || strings.Contains(lowerDesc, "heartbeat") {
		rule := FilterRule{
			Name:        "drop-health-checks",
			Type:        signalType,
			Condition:   `attributes["http.url"] =~ ".*/health.*"`,
			Action:      "drop",
			Description: "Drop health check requests",
			Priority:    2,
		}
		rules = append(rules, rule)
	}
	
	return rules
}

// generatePolicyFilterRules creates filter rules for policy violations
func (rp *RecommendationParser) generatePolicyFilterRules(description string) []FilterRule {
	var rules []FilterRule
	
	lowerDesc := strings.ToLower(description)
	
	if strings.Contains(lowerDesc, "environment") {
		rule := FilterRule{
			Name:        "require-environment-label",
			Type:        SignalTypeTrace,
			Condition:   `resource.attributes["environment"] == nil`,
			Action:      "drop",
			Description: "Drop signals without environment label",
			Priority:    1,
		}
		rules = append(rules, rule)
	}
	
	if strings.Contains(lowerDesc, "service") {
		rule := FilterRule{
			Name:        "require-service-name",
			Type:        SignalTypeTrace,
			Condition:   `resource.attributes["service.name"] == nil`,
			Action:      "drop",
			Description: "Drop signals without service name",
			Priority:    1,
		}
		rules = append(rules, rule)
	}
	
	return rules
}

// generateRecommendationID generates a unique ID for a recommendation
func (rp *RecommendationParser) generateRecommendationID(rec Recommendation) string {
	hash := md5.Sum([]byte(rec.Description + string(rec.Type) + string(rec.Priority)))
	return fmt.Sprintf("rec-%s", hex.EncodeToString(hash[:])[:8])
}

// generateSummary generates a summary of all recommendations
func (rp *RecommendationParser) generateSummary(recommendations []Recommendation) Summary {
	summary := Summary{
		TotalRecommendations: len(recommendations),
		ByType:               make(map[RecommendationType]int),
		ByPriority:           make(map[Priority]int),
		RecommendedActions:   make([]string, 0),
	}
	
	highestPriority := PriorityLow
	totalSavings := 0.0
	
	for _, rec := range recommendations {
		// Count by type
		summary.ByType[rec.Type]++
		
		// Count by priority
		summary.ByPriority[rec.Priority]++
		
		// Track highest priority
		if rec.Priority == PriorityCritical || (rec.Priority == PriorityHigh && highestPriority != PriorityCritical) ||
			(rec.Priority == PriorityMedium && highestPriority == PriorityLow) {
			highestPriority = rec.Priority
		}
		
		// Parse savings percentage
		if rec.Impact.DataVolumeReduction != "" {
			if matches := rp.patterns["percentage"].FindStringSubmatch(rec.Impact.DataVolumeReduction); len(matches) > 1 {
				if savings, err := strconv.ParseFloat(matches[1], 64); err == nil {
					totalSavings += savings
				}
			}
		}
		
		// Collect actions
		if rec.Description != "" && len(summary.RecommendedActions) < 5 {
			summary.RecommendedActions = append(summary.RecommendedActions, rec.Description)
		}
	}
	
	summary.HighestPriority = highestPriority
	
	if totalSavings > 0 {
		summary.EstimatedSavings = fmt.Sprintf("%.1f%%", totalSavings/float64(len(recommendations)))
	} else {
		summary.EstimatedSavings = "10-30%"
	}
	
	return summary
}

// defaultLogger provides a simple logger implementation
type defaultLogger struct{}

func (dl *defaultLogger) Info(msg string, args ...interface{}) {
	fmt.Printf("[INFO] "+msg+"\n", args...)
}

func (dl *defaultLogger) Warn(msg string, args ...interface{}) {
	fmt.Printf("[WARN] "+msg+"\n", args...)
}

func (dl *defaultLogger) Error(msg string, args ...interface{}) {
	fmt.Printf("[ERROR] "+msg+"\n", args...)
}

func (dl *defaultLogger) Debug(msg string, args ...interface{}) {
	// Debug messages are disabled by default
}