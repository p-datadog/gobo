# Loaded at runtime by config/initializers/zzy_symdb_hot_load_test.rb's
# /symdb_hot_load_test/define_class?n=2 endpoint, to exercise the
# TracePoint :class hot-load hook in PR #5697.
class HotLoad2
  CONST_2 = 2.freeze
  def hot_load_method_2(arg)
    arg + 2
  end
end
