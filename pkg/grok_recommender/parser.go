package grok_recommender

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

// RecommendationParser parses Grok API responses and generates OTel filter rules
type RecommendationParser struct {
	yamlTemplate string
}

// Recommendation represents a parsed recommendation from Grok
type Recommendation struct {
	ID             string                `json:"id"`
	Type           RecommendationType    `json:"type"`
	Priority       Priority              `json:"priority"`
	Description    string                `json:"description"`
	Rationale      string                `json:"rationale"`
	FilterRules    []FilterRule          `json:"filter_rules"`
	EstimatedSaving string               `json:"estimated_saving"`
	CreatedAt      time.Time             `json:"created_at"`
}

// RecommendationType represents the type of recommendation
type RecommendationType string

const (
	RecommendationTypeDropSignal     RecommendationType = "drop_signal"
	RecommendationTypeLabelPolicy    RecommendationType = "label_policy"
	RecommendationTypeNoiseReduction RecommendationType = "noise_reduction"
	RecommendationTypeOptimization   RecommendationType = "optimization"
)

// Priority represents the priority of a recommendation
type Priority string

const (
	PriorityHigh   Priority = "high"
	PriorityMedium Priority = "medium"
	PriorityLow    Priority = "low"
)

// FilterRule represents an OTel filter rule
type FilterRule struct {
	Name        string     `json:"name"`
	Type        SignalType `json:"type"`
	Condition   string     `json:"condition"`
	Action      string     `json:"action"`
	Description string     `json:"description"`
}

// SignalType represents the type of telemetry signal
type SignalType string

const (
	SignalTypeTrace  SignalType = "trace"
	SignalTypeMetric SignalType = "metric"
	SignalTypeLog    SignalType = "log"
)

// ParsedRecommendations contains all parsed recommendations
type ParsedRecommendations struct {
	Recommendations []Recommendation `json:"recommendations"`
	Summary         Summary          `json:"summary"`
	GeneratedAt     time.Time        `json:"generated_at"`
}

// Summary contains a summary of recommendations
type Summary struct {
	TotalRecommendations int                           `json:"total_recommendations"`
	ByType              map[RecommendationType]int    `json:"by_type"`
	ByPriority          map[Priority]int              `json:"by_priority"`
	EstimatedSavings    string                        `json:"estimated_savings"`
}

// NewRecommendationParser creates a new recommendation parser
func NewRecommendationParser() *RecommendationParser {
	return &RecommendationParser{
		yamlTemplate: `
# Generated OTel Filter Rules from Grok Recommendations
# Generated at: %s

processors:
  filter:
    error_mode: ignore
    traces:
      span:
%s
    metrics:
      metric:
%s
    logs:
      log_record:
%s
`,
	}
}

// ParseRecommendations parses Grok API response and extracts recommendations
func (p *RecommendationParser) ParseRecommendations(response *GrokResponse) (*ParsedRecommendations, error) {
	if len(response.Choices) == 0 {
		return nil, fmt.Errorf("no choices in Grok response")
	}
	
	content := response.Choices[0].Message.Content
	recommendations := p.extractRecommendations(content)
	
	summary := p.generateSummary(recommendations)
	
	return &ParsedRecommendations{
		Recommendations: recommendations,
		Summary:         summary,
		GeneratedAt:     time.Now(),
	}, nil
}

// extractRecommendations extracts recommendations from Grok response content
func (p *RecommendationParser) extractRecommendations(content string) []Recommendation {
	var recommendations []Recommendation
	
	// Parse different sections of the response
	signalsToDrop := p.extractSignalsToDropSection(content)
	labelPolicyViolations := p.extractLabelPolicySection(content)
	otelRules := p.extractOtelRulesSection(content)
	rationale := p.extractRationaleSection(content)
	
	// Combine into recommendations
	recommendations = append(recommendations, signalsToDrop...)
	recommendations = append(recommendations, labelPolicyViolations...)
	
	// Add rationale to recommendations
	for i := range recommendations {
		if i < len(rationale) {
			recommendations[i].Rationale = rationale[i]
		}
	}
	
	// Add OTel rules to recommendations
	p.addOtelRules(recommendations, otelRules)
	
	return recommendations
}

// extractSignalsToDropSection extracts signals to drop from the response
func (p *RecommendationParser) extractSignalsToDropSection(content string) []Recommendation {
	var recommendations []Recommendation
	
	// Look for "SIGNALS TO DROP" section
	pattern := regexp.MustCompile(`(?i)SIGNALS TO DROP:?\s*\n(.*?)(?:\n\d+\.|$)`)
	matches := pattern.FindStringSubmatch(content)
	
	if len(matches) > 1 {
		signalsText := matches[1]
		lines := strings.Split(signalsText, "\n")
		
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "   ") {
				continue
			}
			
			if strings.HasPrefix(line, "-") {
				line = strings.TrimPrefix(line, "-")
				line = strings.TrimSpace(line)
				
				rec := Recommendation{
					ID:          fmt.Sprintf("drop-%d", len(recommendations)),
					Type:        RecommendationTypeDropSignal,
					Priority:    p.determinePriority(line),
					Description: line,
					CreatedAt:   time.Now(),
				}
				
				recommendations = append(recommendations, rec)
			}
		}
	}
	
	return recommendations
}

// extractLabelPolicySection extracts label policy violations from the response
func (p *RecommendationParser) extractLabelPolicySection(content string) []Recommendation {
	var recommendations []Recommendation
	
	// Look for "LABEL POLICY VIOLATIONS" section
	pattern := regexp.MustCompile(`(?i)LABEL POLICY VIOLATIONS:?\s*\n(.*?)(?:\n\d+\.|$)`)
	matches := pattern.FindStringSubmatch(content)
	
	if len(matches) > 1 {
		policyText := matches[1]
		lines := strings.Split(policyText, "\n")
		
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "   ") {
				continue
			}
			
			if strings.HasPrefix(line, "-") {
				line = strings.TrimPrefix(line, "-")
				line = strings.TrimSpace(line)
				
				rec := Recommendation{
					ID:          fmt.Sprintf("policy-%d", len(recommendations)),
					Type:        RecommendationTypeLabelPolicy,
					Priority:    p.determinePriority(line),
					Description: line,
					CreatedAt:   time.Now(),
				}
				
				recommendations = append(recommendations, rec)
			}
		}
	}
	
	return recommendations
}

// extractOtelRulesSection extracts OTel filter rules from the response
func (p *RecommendationParser) extractOtelRulesSection(content string) []FilterRule {
	var rules []FilterRule
	
	// Look for YAML filter rules in the response
	yamlPattern := regexp.MustCompile(`(?i)(?:filter|traces|metrics|logs):\s*\n((?:\s*-\s*.*\n?)*?)`)
	matches := yamlPattern.FindAllStringSubmatch(content, -1)
	
	for _, match := range matches {
		if len(match) > 1 {
			rulesText := match[1]
			lines := strings.Split(rulesText, "\n")
			
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if strings.HasPrefix(line, "- ") {
					condition := strings.TrimPrefix(line, "- ")
					condition = strings.Trim(condition, "'\"")
					
					rule := FilterRule{
						Name:        fmt.Sprintf("rule-%d", len(rules)),
						Condition:   condition,
						Action:      "drop",
						Description: fmt.Sprintf("Drop condition: %s", condition),
					}
					
					// Determine signal type based on condition
					if strings.Contains(condition, "span.") || strings.Contains(condition, "trace.") {
						rule.Type = SignalTypeTrace
					} else if strings.Contains(condition, "metric.") {
						rule.Type = SignalTypeMetric
					} else if strings.Contains(condition, "log.") {
						rule.Type = SignalTypeLog
					} else {
						rule.Type = SignalTypeTrace // Default
					}
					
					rules = append(rules, rule)
				}
			}
		}
	}
	
	return rules
}

// extractRationaleSection extracts rationale from the response
func (p *RecommendationParser) extractRationaleSection(content string) []string {
	var rationale []string
	
	// Look for "RATIONALE" section
	pattern := regexp.MustCompile(`(?i)RATIONALE:?\s*\n(.*?)$`)
	matches := pattern.FindStringSubmatch(content)
	
	if len(matches) > 1 {
		rationaleText := matches[1]
		lines := strings.Split(rationaleText, "\n")
		
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			
			if strings.HasPrefix(line, "-") {
				line = strings.TrimPrefix(line, "-")
				line = strings.TrimSpace(line)
				rationale = append(rationale, line)
			}
		}
	}
	
	return rationale
}

// determinePriority determines the priority based on recommendation content
func (p *RecommendationParser) determinePriority(content string) Priority {
	content = strings.ToLower(content)
	
	highPriorityKeywords := []string{"critical", "urgent", "high volume", "expensive", "security", "compliance"}
	mediumPriorityKeywords := []string{"optimize", "improve", "reduce", "performance"}
	
	for _, keyword := range highPriorityKeywords {
		if strings.Contains(content, keyword) {
			return PriorityHigh
		}
	}
	
	for _, keyword := range mediumPriorityKeywords {
		if strings.Contains(content, keyword) {
			return PriorityMedium
		}
	}
	
	return PriorityLow
}

// addOtelRules adds OTel rules to recommendations
func (p *RecommendationParser) addOtelRules(recommendations []Recommendation, rules []FilterRule) {
	for i := range recommendations {
		// Match rules to recommendations based on content similarity
		for _, rule := range rules {
			if p.isRuleRelated(recommendations[i].Description, rule.Condition) {
				recommendations[i].FilterRules = append(recommendations[i].FilterRules, rule)
			}
		}
	}
}

// isRuleRelated checks if a rule is related to a recommendation
func (p *RecommendationParser) isRuleRelated(description, condition string) bool {
	// Simple keyword matching - can be improved with better NLP
	descWords := strings.Fields(strings.ToLower(description))
	condWords := strings.Fields(strings.ToLower(condition))
	
	commonWords := 0
	for _, dWord := range descWords {
		for _, cWord := range condWords {
			if dWord == cWord {
				commonWords++
			}
		}
	}
	
	return commonWords > 0
}

// generateSummary generates a summary of recommendations
func (p *RecommendationParser) generateSummary(recommendations []Recommendation) Summary {
	summary := Summary{
		TotalRecommendations: len(recommendations),
		ByType:              make(map[RecommendationType]int),
		ByPriority:          make(map[Priority]int),
		EstimatedSavings:    "Unknown",
	}
	
	for _, rec := range recommendations {
		summary.ByType[rec.Type]++
		summary.ByPriority[rec.Priority]++
	}
	
	return summary
}

// GenerateYAMLConfig generates YAML configuration for OTel filter processor
func (p *RecommendationParser) GenerateYAMLConfig(recommendations []Recommendation) string {
	var traceFilters, metricFilters, logFilters []string
	
	for _, rec := range recommendations {
		for _, rule := range rec.FilterRules {
			filterLine := fmt.Sprintf("        - '%s'  # %s", rule.Condition, rule.Description)
			
			switch rule.Type {
			case SignalTypeTrace:
				traceFilters = append(traceFilters, filterLine)
			case SignalTypeMetric:
				metricFilters = append(metricFilters, filterLine)
			case SignalTypeLog:
				logFilters = append(logFilters, filterLine)
			}
		}
	}
	
	traceSection := ""
	if len(traceFilters) > 0 {
		traceSection = strings.Join(traceFilters, "\n")
	}
	
	metricSection := ""
	if len(metricFilters) > 0 {
		metricSection = strings.Join(metricFilters, "\n")
	}
	
	logSection := ""
	if len(logFilters) > 0 {
		logSection = strings.Join(logFilters, "\n")
	}
	
	return fmt.Sprintf(p.yamlTemplate, time.Now().Format(time.RFC3339), traceSection, metricSection, logSection)
}