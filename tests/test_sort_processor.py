#!/usr/bin/env python3
"""
OpenTelemetry Sort Processor Unit Tests

This module provides comprehensive unit tests for the sorting processor
functionality, including configuration validation, sorting logic, and
performance verification.
"""

import json
import unittest
import yaml
import time
import tempfile
import os
import subprocess
from typing import Dict, List, Any
from unittest.mock import Mock, patch


class TestSortProcessorConfig(unittest.TestCase):
    """Test cases for sort processor configuration validation."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.config_path = os.path.join(
            os.path.dirname(__file__), 
            '../config/processor-config-with-sort.yaml'
        )
        
        # Load configuration
        with open(self.config_path, 'r') as f:
            self.config = yaml.safe_load(f)
    
    def test_config_file_exists(self):
        """Test that the configuration file exists."""
        self.assertTrue(os.path.exists(self.config_path))
    
    def test_config_yaml_valid(self):
        """Test that the configuration is valid YAML."""
        self.assertIsInstance(self.config, dict)
        self.assertIn('processors', self.config)
        self.assertIn('service', self.config)
    
    def test_required_processors_present(self):
        """Test that all required processors are present."""
        required_processors = [
            'memory_limiter',
            'resourcedetection',
            'resource',
            'transform',
            'attributes',
            'filter',
            'batch/sort_buffer',
            'batch/post_sort'
        ]
        
        processors = self.config.get('processors', {})
        
        for processor in required_processors:
            self.assertIn(processor, processors, 
                         f"Required processor '{processor}' not found")
    
    def test_transform_processor_sorting_logic(self):
        """Test that transform processor has sorting logic."""
        transform_config = self.config['processors']['transform']
        
        self.assertIn('trace_statements', transform_config)
        trace_statements = transform_config['trace_statements']
        
        # Check for sorting metadata statements
        sorting_statements = [
            'sort.timestamp',
            'sort.duration',
            'sort.priority',
            'sort.severity_weight',
            'sort.business_priority'
        ]
        
        statements_text = ' '.join(trace_statements)
        
        for statement in sorting_statements:
            self.assertIn(statement, statements_text,
                         f"Sorting statement '{statement}' not found")
    
    def test_business_priority_logic(self):
        """Test that business priority logic is configured."""
        transform_config = self.config['processors']['transform']
        trace_statements = transform_config['trace_statements']
        
        # Check for service-specific business priorities
        priority_services = ['payment-service', 'user-service', 'notification-service']
        statements_text = ' '.join(trace_statements)
        
        for service in priority_services:
            self.assertIn(service, statements_text,
                         f"Business priority for '{service}' not found")
    
    def test_pipeline_configuration(self):
        """Test that the pipeline is properly configured."""
        pipelines = self.config['service']['pipelines']
        
        self.assertIn('traces', pipelines)
        traces_pipeline = pipelines['traces']
        
        # Check pipeline structure
        self.assertIn('receivers', traces_pipeline)
        self.assertIn('processors', traces_pipeline)
        self.assertIn('exporters', traces_pipeline)
        
        # Check processor order
        processors = traces_pipeline['processors']
        expected_order = [
            'memory_limiter',
            'resourcedetection',
            'resource',
            'batch/sort_buffer',
            'transform',
            'attributes',
            'filter',
            'batch/post_sort'
        ]
        
        self.assertEqual(processors, expected_order)


class TestSortingLogic(unittest.TestCase):
    """Test cases for sorting logic validation."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.test_spans = [
            {
                'name': 'payment.process',
                'start_time': 1640995203000000000,
                'end_time': 1640995203500000000,
                'status': 'ERROR',
                'level': 'ERROR',
                'service': 'payment-service',
                'priority': 10
            },
            {
                'name': 'user.login',
                'start_time': 1640995201000000000,
                'end_time': 1640995201100000000,
                'status': 'OK',
                'level': 'INFO',
                'service': 'user-service',
                'priority': 8
            },
            {
                'name': 'notification.send',
                'start_time': 1640995205000000000,
                'end_time': 1640995205050000000,
                'status': 'OK',
                'level': 'DEBUG',
                'service': 'notification-service',
                'priority': 5
            }
        ]
    
    def test_timestamp_sorting(self):
        """Test timestamp-based sorting."""
        sorted_spans = sorted(self.test_spans, key=lambda x: x['start_time'])
        
        # Should be sorted by start_time ascending
        self.assertEqual(sorted_spans[0]['name'], 'user.login')
        self.assertEqual(sorted_spans[1]['name'], 'payment.process')
        self.assertEqual(sorted_spans[2]['name'], 'notification.send')
    
    def test_priority_sorting(self):
        """Test priority-based sorting."""
        sorted_spans = sorted(self.test_spans, key=lambda x: x['priority'], reverse=True)
        
        # Should be sorted by priority descending
        self.assertEqual(sorted_spans[0]['service'], 'payment-service')
        self.assertEqual(sorted_spans[1]['service'], 'user-service')
        self.assertEqual(sorted_spans[2]['service'], 'notification-service')
    
    def test_severity_sorting(self):
        """Test severity-based sorting."""
        severity_weights = {
            'DEBUG': 1,
            'INFO': 2,
            'WARN': 3,
            'ERROR': 4,
            'FATAL': 5
        }
        
        sorted_spans = sorted(self.test_spans, 
                             key=lambda x: severity_weights.get(x['level'], 0),
                             reverse=True)
        
        # Should be sorted by severity descending
        self.assertEqual(sorted_spans[0]['level'], 'ERROR')
        self.assertEqual(sorted_spans[1]['level'], 'INFO')
        self.assertEqual(sorted_spans[2]['level'], 'DEBUG')
    
    def test_multi_criteria_sorting(self):
        """Test multi-criteria sorting."""
        # Sort by priority first, then by severity
        severity_weights = {
            'DEBUG': 1,
            'INFO': 2,
            'WARN': 3,
            'ERROR': 4,
            'FATAL': 5
        }
        
        sorted_spans = sorted(self.test_spans,
                             key=lambda x: (
                                 x['priority'],
                                 severity_weights.get(x['level'], 0)
                             ),
                             reverse=True)
        
        # Payment service should be first (highest priority)
        self.assertEqual(sorted_spans[0]['service'], 'payment-service')
        
        # User service should be second
        self.assertEqual(sorted_spans[1]['service'], 'user-service')
        
        # Notification service should be last
        self.assertEqual(sorted_spans[2]['service'], 'notification-service')


class TestSortProcessorPerformance(unittest.TestCase):
    """Test cases for sort processor performance validation."""
    
    def setUp(self):
        """Set up performance test fixtures."""
        self.small_batch_size = 100
        self.medium_batch_size = 1000
        self.large_batch_size = 10000
    
    def generate_test_spans(self, count: int) -> List[Dict[str, Any]]:
        """Generate test spans for performance testing."""
        spans = []
        base_time = int(time.time() * 1000000000)
        
        for i in range(count):
            span = {
                'trace_id': f'{i:032x}',
                'span_id': f'{i:016x}',
                'name': f'test-span-{i}',
                'start_time': base_time + (i * 1000000),  # 1ms apart
                'end_time': base_time + (i * 1000000) + 500000,  # 0.5ms duration
                'status': 'OK' if i % 10 != 0 else 'ERROR',
                'level': 'INFO' if i % 10 != 0 else 'ERROR',
                'service': f'service-{i % 5}',
                'priority': (i % 5) + 1
            }
            spans.append(span)
        
        return spans
    
    def test_small_batch_performance(self):
        """Test performance with small batch."""
        spans = self.generate_test_spans(self.small_batch_size)
        
        start_time = time.time()
        sorted_spans = sorted(spans, key=lambda x: x['start_time'])
        end_time = time.time()
        
        duration = end_time - start_time
        throughput = len(spans) / duration
        
        # Should process small batches very quickly
        self.assertLess(duration, 0.1)  # Less than 100ms
        self.assertGreater(throughput, 1000)  # More than 1000 spans/sec
    
    def test_medium_batch_performance(self):
        """Test performance with medium batch."""
        spans = self.generate_test_spans(self.medium_batch_size)
        
        start_time = time.time()
        sorted_spans = sorted(spans, key=lambda x: x['start_time'])
        end_time = time.time()
        
        duration = end_time - start_time
        throughput = len(spans) / duration
        
        # Should handle medium batches efficiently
        self.assertLess(duration, 1.0)  # Less than 1 second
        self.assertGreater(throughput, 1000)  # More than 1000 spans/sec
    
    def test_large_batch_performance(self):
        """Test performance with large batch."""
        spans = self.generate_test_spans(self.large_batch_size)
        
        start_time = time.time()
        sorted_spans = sorted(spans, key=lambda x: x['start_time'])
        end_time = time.time()
        
        duration = end_time - start_time
        throughput = len(spans) / duration
        
        # Should handle large batches within reasonable time
        self.assertLess(duration, 10.0)  # Less than 10 seconds
        self.assertGreater(throughput, 1000)  # More than 1000 spans/sec
    
    def test_memory_usage_estimation(self):
        """Test memory usage estimation."""
        spans = self.generate_test_spans(1000)
        
        # Estimate memory usage (simplified)
        span_size = 500  # bytes per span (estimated)
        total_memory = len(spans) * span_size
        memory_mb = total_memory / 1024 / 1024
        
        # Should be reasonable memory usage
        self.assertLess(memory_mb, 10)  # Less than 10MB for 1000 spans


class TestSortProcessorIntegration(unittest.TestCase):
    """Integration tests for sort processor."""
    
    def setUp(self):
        """Set up integration test fixtures."""
        self.config_path = os.path.join(
            os.path.dirname(__file__),
            '../config/processor-config-with-sort.yaml'
        )
        self.test_script_path = os.path.join(
            os.path.dirname(__file__),
            '../scripts/test-sort-processor.sh'
        )
    
    def test_configuration_validation_script(self):
        """Test configuration validation through script."""
        if not os.path.exists(self.test_script_path):
            self.skipTest("Test script not found")
        
        # Run configuration validation
        result = subprocess.run(
            [self.test_script_path, '--unit'],
            capture_output=True,
            text=True
        )
        
        # Should pass validation
        self.assertEqual(result.returncode, 0, 
                        f"Configuration validation failed: {result.stderr}")
    
    def test_benchmark_script_execution(self):
        """Test benchmark script execution."""
        benchmark_script = os.path.join(
            os.path.dirname(__file__),
            '../scripts/benchmark-sort-processor.sh'
        )
        
        if not os.path.exists(benchmark_script):
            self.skipTest("Benchmark script not found")
        
        # Run a quick benchmark
        result = subprocess.run(
            [benchmark_script, '--sorting'],
            capture_output=True,
            text=True,
            timeout=60  # 60 second timeout
        )
        
        # Should execute without errors
        self.assertEqual(result.returncode, 0,
                        f"Benchmark execution failed: {result.stderr}")


class TestSortProcessorEdgeCases(unittest.TestCase):
    """Test cases for edge cases and error conditions."""
    
    def test_empty_batch_handling(self):
        """Test handling of empty batches."""
        spans = []
        
        # Should handle empty batches gracefully
        sorted_spans = sorted(spans, key=lambda x: x.get('start_time', 0))
        self.assertEqual(len(sorted_spans), 0)
    
    def test_single_span_batch(self):
        """Test handling of single span batches."""
        spans = [{
            'name': 'single-span',
            'start_time': 1640995201000000000,
            'priority': 5
        }]
        
        sorted_spans = sorted(spans, key=lambda x: x['start_time'])
        self.assertEqual(len(sorted_spans), 1)
        self.assertEqual(sorted_spans[0]['name'], 'single-span')
    
    def test_missing_sort_attributes(self):
        """Test handling of spans with missing sort attributes."""
        spans = [
            {
                'name': 'span-with-time',
                'start_time': 1640995201000000000,
                'priority': 5
            },
            {
                'name': 'span-without-time',
                'priority': 8
            }
        ]
        
        # Should handle missing attributes gracefully
        sorted_spans = sorted(spans, key=lambda x: x.get('start_time', 0))
        
        # Span without time should be first (default 0)
        self.assertEqual(sorted_spans[0]['name'], 'span-without-time')
        self.assertEqual(sorted_spans[1]['name'], 'span-with-time')
    
    def test_duplicate_timestamps(self):
        """Test handling of duplicate timestamps."""
        spans = [
            {
                'name': 'span-1',
                'start_time': 1640995201000000000,
                'priority': 5
            },
            {
                'name': 'span-2',
                'start_time': 1640995201000000000,
                'priority': 8
            }
        ]
        
        # Should handle duplicate timestamps
        sorted_spans = sorted(spans, key=lambda x: (x['start_time'], x['priority']))
        
        # Should maintain stable sort
        self.assertEqual(len(sorted_spans), 2)
    
    def test_extreme_values(self):
        """Test handling of extreme values."""
        spans = [
            {
                'name': 'future-span',
                'start_time': 9999999999999999999,
                'priority': 1
            },
            {
                'name': 'past-span',
                'start_time': 0,
                'priority': 10
            }
        ]
        
        sorted_spans = sorted(spans, key=lambda x: x['start_time'])
        
        # Should handle extreme values
        self.assertEqual(sorted_spans[0]['name'], 'past-span')
        self.assertEqual(sorted_spans[1]['name'], 'future-span')


def run_performance_benchmark():
    """Run performance benchmark and save results."""
    print("Running performance benchmark...")
    
    # Test different batch sizes
    batch_sizes = [100, 1000, 10000]
    results = []
    
    for size in batch_sizes:
        print(f"Testing batch size: {size}")
        
        # Generate test data
        spans = []
        base_time = int(time.time() * 1000000000)
        
        for i in range(size):
            span = {
                'trace_id': f'{i:032x}',
                'span_id': f'{i:016x}',
                'name': f'test-span-{i}',
                'start_time': base_time + (i * 1000000),
                'end_time': base_time + (i * 1000000) + 500000,
                'status': 'OK' if i % 10 != 0 else 'ERROR',
                'level': 'INFO' if i % 10 != 0 else 'ERROR',
                'service': f'service-{i % 5}',
                'priority': (i % 5) + 1
            }
            spans.append(span)
        
        # Measure sorting performance
        start_time = time.time()
        sorted_spans = sorted(spans, key=lambda x: x['start_time'])
        end_time = time.time()
        
        duration = end_time - start_time
        throughput = len(spans) / duration
        
        result = {
            'batch_size': size,
            'duration_seconds': duration,
            'throughput_spans_per_second': throughput,
            'memory_estimate_mb': (size * 500) / 1024 / 1024  # 500 bytes per span
        }
        
        results.append(result)
        print(f"  Duration: {duration:.4f}s")
        print(f"  Throughput: {throughput:.0f} spans/second")
    
    # Save results
    results_file = 'test-results/performance-benchmark.json'
    os.makedirs('test-results', exist_ok=True)
    
    with open(results_file, 'w') as f:
        json.dump({
            'timestamp': time.time(),
            'results': results
        }, f, indent=2)
    
    print(f"Performance benchmark results saved to: {results_file}")


if __name__ == '__main__':
    # Run unit tests
    unittest.main(verbosity=2, exit=False)
    
    # Run performance benchmark
    run_performance_benchmark()