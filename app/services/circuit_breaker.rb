class CircuitBreaker
  STATE_CLOSED = 'closed'
  STATE_OPEN = 'open'
  STATE_HALF_OPEN = 'half_open'

  class CircuitBreakerOpenError < StandardError; end

  def initialize(redis = Redis.current, failure_threshold: 5, timeout: 30)
    @redis = redis
    @failure_threshold = failure_threshold
    @timeout = timeout
  end

  def call(key)
    state = current_state(key)

    case state
    when STATE_OPEN
      if should_attempt_reset?(key)
        set_state(key, STATE_HALF_OPEN)
      else
        raise CircuitBreakerOpenError, "Circuit breaker is open for #{key}"
      end
    end

    begin
      result = yield
      on_success(key)
      result
    rescue => e
      on_failure(key)
      raise e
    end
  end

  def current_state(key)
    @redis.get("circuit_breaker:#{key}:state") || STATE_CLOSED
  end

  def current_failure_count(key)
    failures_key = "circuit_breaker:#{key}:failures"
    (@redis.get(failures_key) || 0).to_i
  end

  def reset(key)
    @redis.multi do |multi|
      multi.del("circuit_breaker:#{key}:failures")
      multi.del("circuit_breaker:#{key}:state")
      multi.del("circuit_breaker:#{key}:opened_at")
    end
  end

  private

    def on_success(key)
      @redis.multi do |multi|
        multi.del("circuit_breaker:#{key}:failures")
        multi.set("circuit_breaker:#{key}:state", STATE_CLOSED)
      end
    end

    def on_failure(key)
      failures_key = "circuit_breaker:#{key}:failures"
      failure_count = @redis.incr(failures_key)
      @redis.expire(failures_key, @timeout * 2)

      if failure_count >= @failure_threshold
        @redis.multi do |multi|
          multi.set("circuit_breaker:#{key}:state", STATE_OPEN)
          multi.set("circuit_breaker:#{key}:opened_at", Time.now.to_i)
          multi.expire("circuit_breaker:#{key}:opened_at", @timeout * 2)
        end
      end
    end

    def should_attempt_reset?(key)
      opened_at = @redis.get("circuit_breaker:#{key}:opened_at")
      return false unless opened_at

      Time.now.to_i - opened_at.to_i > @timeout
    end

    def set_state(key, state)
      @redis.set("circuit_breaker:#{key}:state", state)
    end
end
