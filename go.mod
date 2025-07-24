module github.com/ChaosKyle/otel-dynamic-processors-lab

go 1.21

require (
	github.com/spf13/cobra v1.8.0
	go.opentelemetry.io/collector/component v0.91.0
	go.opentelemetry.io/collector/processor v0.91.0
	go.opentelemetry.io/collector/pdata v1.0.0
	go.uber.org/zap v1.26.0
)

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
	go.uber.org/multierr v1.11.0 // indirect
)

// Local development replace directives
// Remove these when contributing to upstream
replace github.com/ChaosKyle/otel-dynamic-processors-lab/pkg/grok_recommender => ./pkg/grok_recommender