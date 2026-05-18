namespace :stress do
  desc 'Generate N synthetic classes under app/stress/generated/ (default N=2500)'
  task :gen, [:count] => :environment do |_, args|
    count = (args[:count] || ENV['N'] || 2500).to_i
    out_dir = Rails.root.join('app', 'stress', 'generated')
    FileUtils.rm_rf(out_dir)
    FileUtils.mkdir_p(out_dir)

    count.times do |i|
      idx = format('%05d', i)
      File.write(out_dir.join("klass_#{idx}.rb"), class_source(idx))
    end

    puts "Generated #{count} classes under #{out_dir}"
  end

  def class_source(idx)
    <<~RUBY
      module Stress
        module Generated
          module Mod#{idx}
            CONST_A = 'value-a-#{idx}'
            CONST_B = #{idx.to_i}
            CONST_C = [1, 2, 3, 4, 5].freeze
            CONST_D = { key: :value_#{idx} }.freeze
            CONST_E = :sym_#{idx}

            class Klass#{idx}
              ATTR_LIST = %w[a b c d e f].freeze
              MAX_RETRIES = 3
              TIMEOUT = 30

              attr_accessor :name, :value, :enabled

              def initialize(name = nil, value = 0)
                @name = name
                @value = value
                @enabled = true
                @cache = {}
                @retries = 0
              end

              def method_one(arg)
                arg * 2 + CONST_B
              end

              def method_two(a, b)
                a + b
              end

              def method_three(items)
                items.map { |x| x.to_s }
              end

              def method_four(key, value)
                @cache[key] = value
              end

              def method_five(key)
                @cache[key]
              end

              def method_six
                @retries += 1
                @retries
              end

              def method_seven(threshold)
                @value > threshold
              end

              def method_eight(items, sep = ',')
                items.join(sep)
              end

              def method_nine(hash)
                hash.transform_values { |v| v.to_s.upcase }
              end

              def method_ten
                ATTR_LIST.sample
              end
            end

            class Helper#{idx}
              def transform(x); x.to_s; end
              def combine(a, b); "\#{a}-\#{b}"; end
              def empty?; @items.nil? || @items.empty?; end
            end
          end
        end
      end
    RUBY
  end
end
