# Queue#pop(arg) dispatches by truthiness, not by presence: the arg selects
# no_wait vs blocking, and any side effect in the arg expression runs
# exactly once. CRuby and Spinel AOT both print "ok" with the same lines.
#
#   pop(true)   -> no_wait (sp_Queue_pop_nb)        # covered by queue_local_pop_nb
#   pop(false)  -> blocking  (sp_Queue_pop)
#   pop(nil)    -> blocking  (sp_Queue_pop, nil is falsy)
#   pop(<expr>) -> the arg expression runs once, even though the dispatch
#                  only reads the truthiness

# false on a non-empty queue returns the head value, not nil, not ThreadError
q = Queue.new
q.push("from-arg")
print q.pop(false) == "from-arg" ? "ok" : "FAIL"
print "\n"

# nil on a non-empty queue returns the head value
r = Queue.new
r.push("from-nil")
print r.pop(nil) == "from-nil" ? "ok" : "FAIL"
print "\n"

# The dispatch reads the arg's TRUTHINESS, not its identity: an arg of
# 1 (Integer, truthy) is no_wait and raises ThreadError on an empty
# queue. Confirms the arg actually steers the dispatch.
s = Queue.new
got = nil
begin
  got = s.pop(1)             # 1 is truthy -> no_wait -> raise
rescue ThreadError
  got = :thread_error
end
print got == :thread_error ? "ok" : "FAIL"
print "\n"

# The arg expression must run exactly once. A side-effecting method call
# in the arg increments a counter; the counter should be 1 after the pop.
class Ticker
  def initialize; @n = 0; end
  attr_reader :n
  def value; @n += 1; true; end    # truthy, with a side effect
end

t = Ticker.new
q2 = Queue.new
q2.push("payload")
v = q2.pop(t.value)               # arg expression t.value runs once
print v == "payload" ? "ok" : "FAIL"
print "\n"
print t.n == 1 ? "ok" : "FAIL"
print "\n"

# Same, but with a falsy arg that still has a side effect: the side
# effect runs, then the blocking pop dispatches and returns the head.
t2 = Ticker.new
def t2.false_value; @n ||= 0; @n += 1; false; end
q3 = Queue.new
q3.push("from-false-arg")
v = q3.pop(t2.false_value)
print v == "from-false-arg" ? "ok" : "FAIL"
print "\n"
print t2.n == 1 ? "ok" : "FAIL"
print "\n"
