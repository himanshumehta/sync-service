class RateLimiter
  def initialize(redis = Redis.current, default_limit: 60, window_size: 60)
    @redis = redis
    @default_limit = default_limit
    @window_size = window_size
    @limits = {}
  end

  def set_limit(key, limit)
    @limits[key] = limit
  end

  def allow?(key)
    limit = @limits[key] || @default_limit
    rate_limit_key = "rate_limit:#{key}"

    # Sliding window implementation
    now = Time.now.to_i
    window_start = now - @window_size

    @redis.multi do |multi|
      # Remove old entries
      multi.zremrangebyscore(rate_limit_key, 0, window_start)
      # Count current entries
      multi.zcard(rate_limit_key)
      # Add current request
      multi.zadd(rate_limit_key, now, "#{now}-#{SecureRandom.hex(4)}")
      # Set expiry
      multi.expire(rate_limit_key, @window_size * 2)
    end.then do |results|
      current_count = results[1] || 0
      current_count < limit
    end
  end

  def current_usage(key)
    rate_limit_key = "rate_limit:#{key}"
    now = Time.now.to_i
    window_start = now - @window_size

    @redis.zcount(rate_limit_key, window_start, now)
  end

  def reset(key)
    rate_limit_key = "rate_limit:#{key}"
    @redis.del(rate_limit_key)
  end
end
