# load_test.rb - Run with: rails runner script/enqueue_load_test.rb

puts " Creating 1000 contacts with 20 threads..."
start_time = Time.now
success = 0
sync_failures = 0
mutex = Mutex.new

# Add some contacts without company to trigger sync rule failures
companies = [ nil, nil, nil, "TechCorp", "DataInc" ]  # 60% no company

threads = 5.times.map do |thread_id|
  Thread.new do
    thread_success = 0
    thread_sync_failures = 0

    100.times do |i|
      begin
        contact = Contact.create!(
          email: "test#{thread_id}_#{i}_#{Time.now.to_i}@example.com",
          first_name: "Test#{thread_id}_#{i}",
          last_name: "User",
          status: [ :active, :inactive ].sample
        )

        # Add company field (some will be nil to test sync rules)
        contact.update!(company: companies.sample)

        thread_success += 1
        print "✅"

        # Check if sync would actually happen
        applicable_crms = SyncRulesEngine.applicable_crms(contact, 'CREATE')
        if applicable_crms.empty?
          thread_sync_failures += 1
          print "⚠️"  # Sync rule filtered out
        end

      rescue => e
        print "❌"
        puts "\nContact creation failed: #{e.message}"
      end
    end

    mutex.synchronize do
      success += thread_success
      sync_failures += thread_sync_failures
    end
  end
end

threads.each(&:join)

duration = Time.now - start_time
rate = (success / duration).round(1)

puts "\n RESULTS:"
puts "✅ Contacts Created: #{success}/500"
puts "⚠️  Sync Rule Filtered: #{sync_failures}"
puts "⏱️  Time: #{duration.round(1)}s (#{rate}/sec)"

# Show what's actually in the queue
if defined?(Sidekiq::Stats)
  stats = Sidekiq::Stats.new
  puts " Sidekiq: #{stats.enqueued} queued, #{stats.processed} processed, #{stats.failed} failed"
end

puts "\n To see CRM failures, process the queue:"
puts "Sidekiq::Worker.drain_all  # Process all queued jobs"
puts "\n Cleanup: Contact.where(\"email LIKE 'test%'\").destroy_all"
