RSpec.configure do |config|
  config.before(:each) do
    Redis.current.flushdb
  end
end
