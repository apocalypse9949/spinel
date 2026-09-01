inner = nil
begin
  begin
    raise 'boom'
  rescue => e
    err = StandardError.new('wrapped: ' + e.message)
    err.set_backtrace(['frame 1: setup', 'frame 2: dispatch', 'frame 3: raise'])
    inner = err
  end
end

bt = inner.backtrace
raise 'backtrace not an Array' unless bt.is_a?(Array)
raise 'wrong size: ' + bt.size.to_s unless bt.size == 3
expected = ['frame 1: setup', 'frame 2: dispatch', 'frame 3: raise']
raise 'wrong content' unless bt == expected
sep = ' | '
raise 'join wrong: ' + bt.join(sep) unless bt.join(sep) == expected.join(sep)
puts 'ok'
