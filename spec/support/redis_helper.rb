RSpec.configure do |config|
  config.before(:each) do
    Redis.current.flushdb if defined?(Redis)
  end

  config.after(:suite) do
    Redis.current.flushdb if defined?(Redis)
  end
end
