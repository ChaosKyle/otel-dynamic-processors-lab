package grok_recommender

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// GrokClient handles communication with the xAI Grok API
type GrokClient struct {
	apiKey     string
	baseURL    string
	httpClient *http.Client
}

// GrokRequest represents a request to the Grok API
type GrokRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
	Stream   bool      `json:"stream"`
}

// Message represents a message in the conversation
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// GrokResponse represents the response from the Grok API
type GrokResponse struct {
	ID      string   `json:"id"`
	Object  string   `json:"object"`
	Created int64    `json:"created"`
	Model   string   `json:"model"`
	Choices []Choice `json:"choices"`
	Usage   Usage    `json:"usage"`
}

// Choice represents a choice in the response
type Choice struct {
	Index        int     `json:"index"`
	Message      Message `json:"message"`
	FinishReason string  `json:"finish_reason"`
}

// Usage represents token usage information
type Usage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

// NewGrokClient creates a new Grok API client
func NewGrokClient(apiKey string) *GrokClient {
	return &GrokClient{
		apiKey:  apiKey,
		baseURL: "https://api.x.ai/v1",
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// GenerateRecommendations sends telemetry data to Grok and gets recommendations
func (c *GrokClient) GenerateRecommendations(ctx context.Context, telemetryData string, policies []string) (*GrokResponse, error) {
	prompt := c.buildPrompt(telemetryData, policies)
	
	request := GrokRequest{
		Model: "grok-beta",
		Messages: []Message{
			{
				Role:    "system",
				Content: "You are an expert OpenTelemetry observability engineer specializing in telemetry optimization and filtering. You analyze telemetry data and provide actionable recommendations for filtering out noise and enforcing label policies.",
			},
			{
				Role:    "user",
				Content: prompt,
			},
		},
		Stream: false,
	}
	
	return c.sendRequest(ctx, request)
}

// buildPrompt constructs the prompt for Grok API
func (c *GrokClient) buildPrompt(telemetryData string, policies []string) string {
	prompt := fmt.Sprintf(`
Analyze this OpenTelemetry telemetry sample and provide specific recommendations:

TELEMETRY SAMPLE:
%s

LABEL POLICIES TO ENFORCE:
%s

Please provide recommendations in the following format:

1. SIGNALS TO DROP:
   - Identify low-value metrics, noisy logs, or unnecessary traces
   - Provide specific filter conditions

2. LABEL POLICY VIOLATIONS:
   - Identify data that doesn't comply with label policies
   - Suggest corrections or drops for non-compliant attributes

3. OTEL FILTER RULES:
   - Generate YAML configuration snippets for OpenTelemetry filter processor
   - Use proper OTTL (OpenTelemetry Transformation Language) syntax
   - Include both trace and metric filter rules

4. RATIONALE:
   - Explain why each recommendation improves observability
   - Estimate potential data volume reduction

Focus on actionable, production-ready recommendations that can be implemented immediately.
`, telemetryData, formatPolicies(policies))

	return prompt
}

// formatPolicies formats the policies for the prompt
func formatPolicies(policies []string) string {
	if len(policies) == 0 {
		return "No specific policies provided - use best practices"
	}
	
	result := ""
	for i, policy := range policies {
		result += fmt.Sprintf("   %d. %s\n", i+1, policy)
	}
	return result
}

// sendRequest sends a request to the Grok API
func (c *GrokClient) sendRequest(ctx context.Context, request GrokRequest) (*GrokResponse, error) {
	jsonData, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}
	
	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/chat/completions", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API request failed with status %d: %s", resp.StatusCode, string(body))
	}
	
	var response GrokResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	
	return &response, nil
}

// ValidateAPIKey checks if the API key is valid by making a simple request
func (c *GrokClient) ValidateAPIKey(ctx context.Context) error {
	request := GrokRequest{
		Model: "grok-beta",
		Messages: []Message{
			{
				Role:    "user",
				Content: "Hello",
			},
		},
		Stream: false,
	}
	
	_, err := c.sendRequest(ctx, request)
	return err
}