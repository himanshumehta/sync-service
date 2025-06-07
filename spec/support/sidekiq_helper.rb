require 'sidekiq/testing'

RSpec.configure do |config|
  config.before(:each) do
    Sidekiq::Worker.clear_all
  end

  config.around(:each, :sidekiq_inline) do |example|
    Sidekiq::Testing.inline! do
      example.run
    end
  end

  config.around(:each, :sidekiq_fake) do |example|
    Sidekiq::Testing.fake! do
      example.run
    end
  end
end
