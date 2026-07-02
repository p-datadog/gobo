# DI method-probe demo targets. Both methods are invoked on every home page
# load (StaticPagesController#invoke_probe_demo), so a method probe set on
# either one fires whenever the home page is hit. See the Probe Instructions
# page (ProbeInstructionsController) for the resolved coordinates.
#
# One argument of each method is a complex object with nested attributes, an
# array, and a hash, so captured snapshots and capture expressions exercise
# reference depth, collection size, and field count.
class ProbeDemo
  class Account
    attr_reader :id, :name, :roles, :profile

    def initialize(id:, name:, roles:, profile:)
      @id = id
      @name = name
      @roles = roles
      @profile = profile
    end
  end

  class Profile
    attr_reader :email, :tier, :preferences

    def initialize(email:, tier:, preferences:)
      @email = email
      @tier = tier
      @preferences = preferences
    end
  end

  class SearchFilter
    attr_reader :field, :values, :case_sensitive

    def initialize(field:, values:, case_sensitive:)
      @field = field
      @values = values
      @case_sensitive = case_sensitive
    end
  end

  # Probe target exercising positional arguments; +account+ is a complex object.
  def args(account, action, count)
    "account=#{account.name} action=#{action} count=#{count}"
  end

  # Probe target exercising keyword arguments; +filter+ is a complex object.
  def kw_args(query:, filter:, limit:)
    "query=#{query} filter=#{filter.field} limit=#{limit}"
  end
end
