class ExpensiveModel
  attr_accessor :data, :n

  # Fibonacci of 36 takes approximately 1 second on typical hardware
  # Adjust this value if needed: 35 (~0.5s), 36 (~1s), 37 (~1.5s), 38 (~2.5s)
  DEFAULT_FIBONACCI_N = 36

  def initialize(data: {}, n: DEFAULT_FIBONACCI_N)
    @data = data
    @n = n
  end

  def process
    result = {
      timestamp: Time.now,
      data: @data,
      computation_level: @n,
    }
    result
  end

  # Naive recursive Fibonacci (intentionally slow for testing)
  def self.fibonacci(n)
    return n if n <= 1
    fibonacci(n - 1) + fibonacci(n - 2)
  end
end
