# Loaded at runtime by config/initializers/zzy_symdb_hot_load_test.rb's
# /symdb_hot_load_test/define_class?n=5 endpoint, to exercise the
# TracePoint :class hot-load hook in PR #5697.
class HotLoad5
  CONST_5 = 5.freeze
  def hot_load_method_5(arg)
    arg + 5
  end
end
