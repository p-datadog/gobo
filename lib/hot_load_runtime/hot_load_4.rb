# Loaded at runtime by config/initializers/zzy_symdb_hot_load_test.rb's
# /symdb_hot_load_test/define_class?n=4 endpoint, to exercise the
# TracePoint :class hot-load hook in PR #5697.
class HotLoad4
  CONST_4 = 4.freeze
  def hot_load_method_4(arg)
    arg + 4
  end
end
