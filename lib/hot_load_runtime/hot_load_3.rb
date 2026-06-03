# Loaded at runtime by config/initializers/zzy_symdb_hot_load_test.rb's
# /symdb_hot_load_test/define_class?n=3 endpoint, to exercise the
# TracePoint :class hot-load hook in PR #5697.
class HotLoad3
  CONST_3 = 3.freeze
  def hot_load_method_3(arg)
    arg + 3
  end
end
