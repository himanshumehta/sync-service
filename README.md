# Sync Service - Quick Setup & Load Testing

## Quick Start
[Problem Documentation](documentation/problem.md)
[Solution Documentation](documentation/problem.md)

### 1. Setup
```bash
git clone <repo>
cd sync_service
bundle install
rails db:create db:migrate
```

## Testing Scripts

### Load test (500 records)
```bash
rails runner script/enqueue_load_test.rb
```
**Output:**
```bash
🚀 Creating 1000 contacts with 20 threads...
✅✅✅✅✅...

 RESULTS:
✅ Contacts Created: 500/500
⚠️  Sync Rule Filtered: 0
⏱️  Time: 1.3s (379.2/sec)

 To see CRM failures, process the queue:
Sidekiq::Worker.drain_all  # Process all queued jobs

 Cleanup: Contact.where("email LIKE 'test%'").destroy_all```
```

### Test all scenarios like rate limiting, circuit breaker, API failures etc
```bash
rails runner script/table_test.rb
```
**Output:** 
```bash
Table-Driven Test: All Scenarios
============================================================

Running 5 test scenarios...

------------------------------------------------------------
   Scenario: Success Case
   Rate Limit: 100, Failure Rate: 0.0, Requests: 5
   Result: ✅✅✅✅✅
   Stats: ✅5 ❌0 🚫0 ⚡0
   Expected: ✅ All Success
   Status: ✅ PASS

------------------------------------------------------------
   Scenario: Rate Limit Hit
   Rate Limit: 3, Failure Rate: 0.0, Requests: 10
   Result: ✅✅✅🚫🚫🚫🚫🚫🚫🚫
   Stats: ✅3 ❌0 🚫7 ⚡0
   Expected: 🚫 Rate Limited
   Status: ✅ PASS

------------------------------------------------------------
   Scenario: Circuit Breaker Opens
   Rate Limit: 100, Failure Rate: 1.0, Requests: 8
   Result: ❌❌❌⚡⚡⚡⚡⚡
   Stats: ✅0 ❌3 🚫0 ⚡5
   Expected: ⚡ Circuit Open
   Status: ✅ PASS

------------------------------------------------------------
   Scenario: Mixed Failures
   Rate Limit: 5, Failure Rate: 0.7, Requests: 10
   Result: ❌❌❌⚡⚡🚫🚫🚫🚫🚫
   Stats: ✅0 ❌3 🚫5 ⚡2
   Expected: ❌🚫⚡ Mixed
   Status: ✅ PASS

------------------------------------------------------------
   Scenario: Circuit Recovery
   Rate Limit: 100, Failure Rate: 0.0, Requests: 3
   🔧 Pre-setup: Triggering circuit breaker...
   Result: ⚡⚡⚡
   Stats: ✅0 ❌0 🚫0 ⚡3
   Expected: ✅ Recovery
   Status: ❌ FAIL

============================================================
 SUMMARY TABLE
============================================================
Scenario             Result          Status     Output
------------------------------------------------------------
Success Case         ✅5 ❌0 🚫0 ⚡0     ✅ PASS     ✅✅✅✅✅
Rate Limit Hit       ✅3 ❌0 🚫7 ⚡0     ✅ PASS     ✅✅✅🚫🚫🚫🚫🚫🚫🚫
Circuit Breaker Open ✅0 ❌3 🚫0 ⚡5     ✅ PASS     ❌❌❌⚡⚡⚡⚡⚡
Mixed Failures       ✅0 ❌3 🚫5 ⚡2     ✅ PASS     ❌❌❌⚡⚡🚫🚫🚫🚫🚫
Circuit Recovery     ✅0 ❌0 🚫0 ⚡3     ❌ FAIL     ⚡⚡⚡
============================================================
```

## Expected Performance
- **Current**: ~400-700 req/sec per instance
- **Target**: 500+ req/sec
- **Scale**: 10+ instances for 300M daily requests

### 2. Start Services
```bash
# Terminal 1: Redis
redis-server

# Terminal 2: Sidekiq
bundle exec sidekiq

# Terminal 3: Rails (optional)
rails server
```

## Cleanup
```ruby
# In rails console
Contact.where("email LIKE 'test%'").destroy_all
```

