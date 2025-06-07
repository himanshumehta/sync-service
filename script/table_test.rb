# load_test.rb - Run with: rails runner script/table_test.rb
# Table-driven test showing all possible outcomes

puts "Table-Driven Test: All Scenarios"
puts "=" * 60

# Test scenarios table
test_scenarios = [
  {
    name: "Success Case",
    rate_limit: 100,
    failure_rate: 0.0,
    circuit_threshold: 5,
    requests: 5,
    expected: "✅ All Success"
  },
  {
    name: "Rate Limit Hit",
    rate_limit: 3,
    failure_rate: 0.0,
    circuit_threshold: 5,
    requests: 10,
    expected: "🚫 Rate Limited"
  },
  {
    name: "Circuit Breaker Opens",
    rate_limit: 100,
    failure_rate: 1.0,
    circuit_threshold: 3,
    requests: 8,
    expected: "⚡ Circuit Open"
  },
  {
    name: "Mixed Failures",
    rate_limit: 5,
    failure_rate: 0.7,
    circuit_threshold: 3,
    requests: 10,
    expected: "❌🚫⚡ Mixed"
  },
  {
    name: "Circuit Recovery",
    rate_limit: 100,
    failure_rate: 0.0,
    circuit_threshold: 3,
    requests: 3,
    expected: "✅ Recovery",
    pre_setup: :trigger_circuit_open
  }
]

def run_scenario(scenario)
  puts "\n" + "-" * 60
  puts "   Scenario: #{scenario[:name]}"
  puts "   Rate Limit: #{scenario[:rate_limit]}, Failure Rate: #{scenario[:failure_rate]}, Requests: #{scenario[:requests]}"

  # Setup fresh Redis state
  redis = Redis.new
  rate_limiter = RateLimiter.new(redis, default_limit: 60, window_size: 60)
  circuit_breaker = CircuitBreaker.new(redis, failure_threshold: scenario[:circuit_threshold], timeout: 2)

  # Clean state
  test_key = "test_#{scenario[:name].downcase.gsub(' ', '_')}"
  rate_limiter.reset(test_key)
  circuit_breaker.reset(test_key)
  rate_limiter.set_limit(test_key, scenario[:rate_limit])

  # Pre-setup if needed (e.g., trigger circuit open)
  if scenario[:pre_setup] == :trigger_circuit_open
    puts "   🔧 Pre-setup: Triggering circuit breaker..."
    3.times do
      begin
        circuit_breaker.call(test_key) do
          raise StandardError, "Forced failure"
        end
      rescue => e
        # Ignore, just triggering failures
      end
    end
  end

  # Set failure rate
  ENV["#{test_key.upcase}_FAILURE_RATE"] = scenario[:failure_rate].to_s
  crm_client = MockCrmClient.new(test_key)

  # Run test
  results = { success: 0, rate_limited: 0, circuit_open: 0, api_failures: 0 }
  output = ""

  scenario[:requests].times do |i|
    begin
      unless rate_limiter.allow?(test_key)
        results[:rate_limited] += 1
        output += "🚫"
        next
      end

      circuit_breaker.call(test_key) do
        crm_client.create_contact({ email: "test#{i}@example.com" })
      end

      results[:success] += 1
      output += "✅"

    rescue CircuitBreaker::CircuitBreakerOpenError
      results[:circuit_open] += 1
      output += "⚡"
    rescue => e
      results[:api_failures] += 1
      output += "❌"
    end

    sleep(0.05)  # Small delay
  end

  puts "   Result: #{output}"
  puts "   Stats: ✅#{results[:success]} ❌#{results[:api_failures]} 🚫#{results[:rate_limited]} ⚡#{results[:circuit_open]}"
  puts "   Expected: #{scenario[:expected]}"

  # Verify expectation
  case scenario[:expected]
  when "✅ All Success"
    status = results[:success] == scenario[:requests] ? "✅ PASS" : "❌ FAIL"
  when "🚫 Rate Limited"
    status = results[:rate_limited] > 0 ? "✅ PASS" : "❌ FAIL"
  when "⚡ Circuit Open"
    status = results[:circuit_open] > 0 ? "✅ PASS" : "❌ FAIL"
  when "❌🚫⚡ Mixed"
    mixed = results[:api_failures] > 0 || results[:rate_limited] > 0 || results[:circuit_open] > 0
    status = mixed ? "✅ PASS" : "❌ FAIL"
  when "✅ Recovery"
    status = results[:success] > 0 ? "✅ PASS" : "❌ FAIL"
  else
    status = "❓ UNKNOWN"
  end

  puts "   Status: #{status}"

  # Clean up ENV
  ENV.delete("#{test_key.upcase}_FAILURE_RATE")

  results.merge(status: status, output: output)
end

# Run all scenarios
puts "\nRunning #{test_scenarios.length} test scenarios...\n"

all_results = test_scenarios.map { |scenario| run_scenario(scenario) }

# Summary table
puts "\n" + "=" * 60
puts " SUMMARY TABLE"
puts "=" * 60
puts "%-20s %-15s %-10s %s" % [ "Scenario", "Result", "Status", "Output" ]
puts "-" * 60

test_scenarios.each_with_index do |scenario, i|
  result = all_results[i]
  stats = "✅#{result[:success]} ❌#{result[:api_failures]} 🚫#{result[:rate_limited]} ⚡#{result[:circuit_open]}"
  puts "%-20s %-15s %-10s %s" % [
    scenario[:name][0..19],
    stats,
    result[:status],
    result[:output][0..20]
  ]
end

puts "=" * 60
