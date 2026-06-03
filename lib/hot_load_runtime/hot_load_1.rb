# Loaded at runtime by config/initializers/zzy_symdb_hot_load_test.rb's
# /symdb_hot_load_test/define_class?n=1 endpoint, to exercise the
# TracePoint :class hot-load hook in PR #5697.
class HotLoad1
  CONST_1 = 1.freeze
  def hot_load_method_1(arg)
    arg + 1
  end
end
