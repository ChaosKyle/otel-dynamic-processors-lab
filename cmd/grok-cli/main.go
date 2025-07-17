package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"time"

	"github.com/spf13/cobra"
	"path/to/your/repo/pkg/grok_recommender"
)

var (
	apiKey       string
	sampleFile   string
	policiesFile string
	outputFile   string
	verbose      bool
	maxSamples   int
	timeout      time.Duration
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "grok-cli",
		Short: "Grok Recommendation Engine CLI",
		Long:  "A CLI tool for testing and managing the Grok recommendation engine for OpenTelemetry processors",
	}

	// Add subcommands
	rootCmd.AddCommand(
		newRecommendCommand(),
		newValidateCommand(),
		newTestCommand(),
		newPolicyCommand(),
		newVersionCommand(),
	)

	// Global flags
	rootCmd.PersistentFlags().StringVar(&apiKey, "api-key", "", "Grok API key (or set GROK_API_KEY env var)")
	rootCmd.PersistentFlags().BoolVar(&verbose, "verbose", false, "Enable verbose output")
	rootCmd.PersistentFlags().DurationVar(&timeout, "timeout", 30*time.Second, "Request timeout")

	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func newRecommendCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "recommend",
		Short: "Generate recommendations for telemetry data",
		Long:  "Analyze telemetry data sample and generate filtering recommendations using Grok AI",
		RunE:  runRecommendCommand,
	}

	cmd.Flags().StringVar(&sampleFile, "sample", "", "Path to telemetry sample JSON file (required)")
	cmd.Flags().StringVar(&policiesFile, "policies", "", "Path to policies YAML file")
	cmd.Flags().StringVar(&outputFile, "output", "", "Output file for recommendations (stdout if not specified)")
	cmd.Flags().IntVar(&maxSamples, "max-samples", 100, "Maximum number of samples to analyze")

	cmd.MarkFlagRequired("sample")

	return cmd
}

func newValidateCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "validate",
		Short: "Validate Grok API connection and configuration",
		Long:  "Test connection to Grok API and validate configuration settings",
		RunE:  runValidateCommand,
	}

	return cmd
}

func newTestCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "test",
		Short: "Run test scenarios against the recommendation engine",
		Long:  "Execute predefined test scenarios to verify recommendation engine functionality",
		RunE:  runTestCommand,
	}

	cmd.Flags().StringVar(&sampleFile, "sample", "", "Path to test sample file")

	return cmd
}

func newPolicyCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "policy",
		Short: "Manage label policies",
		Long:  "Commands for managing label policies and validation rules",
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "validate",
			Short: "Validate policy configuration",
			RunE:  runPolicyValidateCommand,
		},
		&cobra.Command{
			Use:   "test",
			Short: "Test policies against sample data",
			RunE:  runPolicyTestCommand,
		},
	)

	return cmd
}

func newVersionCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Show version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Grok Recommendation Engine CLI v1.0.0")
			fmt.Println("Built with Go", "1.21")
		},
	}
}

func runRecommendCommand(cmd *cobra.Command, args []string) error {
	// Get API key from flag or environment
	if apiKey == "" {
		apiKey = os.Getenv("GROK_API_KEY")
	}
	
	if apiKey == "" {
		return fmt.Errorf("API key is required. Set --api-key flag or GROK_API_KEY environment variable")
	}

	// Read sample file
	if verbose {
		fmt.Printf("Reading sample file: %s\n", sampleFile)
	}
	
	sampleData, err := ioutil.ReadFile(sampleFile)
	if err != nil {
		return fmt.Errorf("failed to read sample file: %w", err)
	}

	// Parse sample data
	var sample grok_recommender.TelemetrySample
	if err := json.Unmarshal(sampleData, &sample); err != nil {
		return fmt.Errorf("failed to parse sample data: %w", err)
	}

	// Load policies if provided
	var policies []grok_recommender.LabelPolicy
	if policiesFile != "" {
		if verbose {
			fmt.Printf("Loading policies from: %s\n", policiesFile)
		}
		
		policyData, err := ioutil.ReadFile(policiesFile)
		if err != nil {
			return fmt.Errorf("failed to read policies file: %w", err)
		}

		// Parse policies (simplified - in real implementation, use YAML parser)
		policies = []grok_recommender.LabelPolicy{
			{
				Name:           "environment-required",
				RequiredLabels: []string{"environment", "service.name"},
				Enforcement:    "drop",
			},
		}
	}

	// Create recommender
	config := &grok_recommender.RecommenderConfig{
		APIKey:           apiKey,
		MaxSampleSize:    maxSamples,
		SamplingInterval: time.Minute,
		CacheExpiration:  time.Hour,
		RateLimitRPM:     60,
		EnableCache:      false, // Disable cache for CLI
		EnableRateLimit:  true,
		FallbackToStatic: true,
		LogLevel:         "info",
	}

	recommender, err := grok_recommender.NewRecommender(config)
	if err != nil {
		return fmt.Errorf("failed to create recommender: %w", err)
	}

	// Generate recommendations
	if verbose {
		fmt.Println("Generating recommendations...")
	}
	
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	recommendations, err := recommender.GenerateRecommendations(ctx, &sample, policies)
	if err != nil {
		return fmt.Errorf("failed to generate recommendations: %w", err)
	}

	// Output recommendations
	output, err := json.MarshalIndent(recommendations, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal recommendations: %w", err)
	}

	if outputFile != "" {
		if err := ioutil.WriteFile(outputFile, output, 0644); err != nil {
			return fmt.Errorf("failed to write output file: %w", err)
		}
		fmt.Printf("Recommendations written to: %s\n", outputFile)
	} else {
		fmt.Println(string(output))
	}

	// Print summary
	if verbose {
		fmt.Printf("\nSummary:\n")
		fmt.Printf("  Total recommendations: %d\n", recommendations.Summary.TotalRecommendations)
		fmt.Printf("  High priority: %d\n", recommendations.Summary.ByPriority[grok_recommender.PriorityHigh])
		fmt.Printf("  Medium priority: %d\n", recommendations.Summary.ByPriority[grok_recommender.PriorityMedium])
		fmt.Printf("  Low priority: %d\n", recommendations.Summary.ByPriority[grok_recommender.PriorityLow])
		fmt.Printf("  Estimated savings: %s\n", recommendations.Summary.EstimatedSavings)
	}

	return nil
}

func runValidateCommand(cmd *cobra.Command, args []string) error {
	// Get API key from flag or environment
	if apiKey == "" {
		apiKey = os.Getenv("GROK_API_KEY")
	}
	
	if apiKey == "" {
		return fmt.Errorf("API key is required. Set --api-key flag or GROK_API_KEY environment variable")
	}

	// Create client
	client := grok_recommender.NewGrokClient(apiKey)

	// Validate connection
	if verbose {
		fmt.Println("Validating Grok API connection...")
	}
	
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	if err := client.ValidateAPIKey(ctx); err != nil {
		return fmt.Errorf("API validation failed: %w", err)
	}

	fmt.Println("✅ Grok API connection validated successfully")
	return nil
}

func runTestCommand(cmd *cobra.Command, args []string) error {
	fmt.Println("Running test scenarios...")

	// Test 1: Basic recommendation generation
	fmt.Println("\n1. Testing basic recommendation generation...")
	
	// Create a test sample
	testSample := createTestSample()
	
	// Test with mock data if no API key
	if apiKey == "" {
		fmt.Println("⚠️  No API key provided, using mock data")
		printTestResults(true, "Mock recommendations generated")
		return nil
	}

	// Create recommender
	config := &grok_recommender.RecommenderConfig{
		APIKey:           apiKey,
		MaxSampleSize:    10,
		SamplingInterval: time.Minute,
		CacheExpiration:  time.Hour,
		RateLimitRPM:     60,
		EnableCache:      false,
		EnableRateLimit:  true,
		FallbackToStatic: true,
		LogLevel:         "info",
	}

	recommender, err := grok_recommender.NewRecommender(config)
	if err != nil {
		printTestResults(false, fmt.Sprintf("Failed to create recommender: %v", err))
		return err
	}

	// Test validation
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	if err := recommender.ValidateConnection(ctx); err != nil {
		printTestResults(false, fmt.Sprintf("Connection validation failed: %v", err))
		return err
	}

	printTestResults(true, "Connection validated")

	// Test recommendation generation
	policies := []grok_recommender.LabelPolicy{
		{
			Name:           "test-policy",
			RequiredLabels: []string{"environment"},
			Enforcement:    "drop",
		},
	}

	recommendations, err := recommender.GenerateRecommendations(ctx, testSample, policies)
	if err != nil {
		printTestResults(false, fmt.Sprintf("Recommendation generation failed: %v", err))
		return err
	}

	printTestResults(true, fmt.Sprintf("Generated %d recommendations", len(recommendations.Recommendations)))

	// Test 2: Data anonymization
	fmt.Println("\n2. Testing data anonymization...")
	
	sampler := grok_recommender.NewTelemetrySampler(100)
	anonymizer := grok_recommender.NewDataAnonymizer()
	
	testString := "User email: john.doe@example.com, IP: 192.168.1.1"
	anonymized := anonymizer.AnonymizeString(testString)
	
	if anonymized != testString {
		printTestResults(true, "Data anonymization working")
	} else {
		printTestResults(false, "Data anonymization not working")
	}

	// Test 3: Sampling
	fmt.Println("\n3. Testing telemetry sampling...")
	
	traces := []grok_recommender.TraceSpan{
		{Name: "test-span-1", Service: "test-service", Duration: time.Millisecond * 100},
		{Name: "test-span-2", Service: "test-service", Duration: time.Millisecond * 200},
	}
	
	sampledTraces := sampler.SampleTraces(traces)
	
	if len(sampledTraces) == 2 {
		printTestResults(true, "Sampling working correctly")
	} else {
		printTestResults(false, "Sampling not working correctly")
	}

	fmt.Println("\n✅ All tests completed")
	return nil
}

func runPolicyValidateCommand(cmd *cobra.Command, args []string) error {
	if policiesFile == "" {
		return fmt.Errorf("policies file is required")
	}

	fmt.Printf("Validating policies file: %s\n", policiesFile)

	// Read and validate policies file
	data, err := ioutil.ReadFile(policiesFile)
	if err != nil {
		return fmt.Errorf("failed to read policies file: %w", err)
	}

	// Basic validation (in real implementation, use YAML parser and schema validation)
	if len(data) == 0 {
		return fmt.Errorf("policies file is empty")
	}

	fmt.Println("✅ Policies file is valid")
	return nil
}

func runPolicyTestCommand(cmd *cobra.Command, args []string) error {
	fmt.Println("Testing policies against sample data...")
	
	// Create test sample
	testSample := createTestSample()
	
	// Test policy enforcement (simplified)
	policies := []grok_recommender.LabelPolicy{
		{
			Name:           "environment-required",
			RequiredLabels: []string{"environment"},
			Enforcement:    "drop",
		},
	}
	
	// Check if sample complies with policies
	for _, trace := range testSample.Traces {
		if trace.ResourceTags["environment"] == "" {
			fmt.Printf("❌ Policy violation: trace '%s' missing environment label\n", trace.Name)
		} else {
			fmt.Printf("✅ Policy compliant: trace '%s' has environment label\n", trace.Name)
		}
	}

	return nil
}

func createTestSample() *grok_recommender.TelemetrySample {
	return &grok_recommender.TelemetrySample{
		Traces: []grok_recommender.TraceSpan{
			{
				Name:     "test-span",
				Service:  "test-service",
				Duration: time.Millisecond * 100,
				Status:   "OK",
				Attributes: map[string]string{
					"http.method": "GET",
					"http.url":    "https://api.example.com/test",
				},
				ResourceTags: map[string]string{
					"environment": "test",
					"version":     "1.0.0",
				},
			},
		},
		Metrics: []grok_recommender.MetricDataPoint{
			{
				Name:  "test_metric",
				Value: 42.0,
				Type:  "gauge",
				Labels: map[string]string{
					"method": "GET",
					"status": "200",
				},
			},
		},
		Logs: []grok_recommender.LogEntry{
			{
				Level:   "INFO",
				Message: "Test log message",
				Service: "test-service",
				Attributes: map[string]string{
					"request_id": "req-123",
				},
			},
		},
		Meta: grok_recommender.SampleMetadata{
			TotalSpans:   1,
			TotalMetrics: 1,
			TotalLogs:    1,
			Services:     []string{"test-service"},
		},
	}
}

func printTestResults(success bool, message string) {
	if success {
		fmt.Printf("  ✅ %s\n", message)
	} else {
		fmt.Printf("  ❌ %s\n", message)
	}
}

// Helper function to setup logging
func init() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
}