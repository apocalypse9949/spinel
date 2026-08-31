class C
  def initialize
    @cv = ConditionVariable.new
    @m  = Mutex.new
  end
  def go
    @m.synchronize { @cv.wait(@m, 0) }
    puts "ok"
  end
end
c = C.new
t = Thread.new { c.go }
t.join
