require "tmpdir"

# Dir.tmpdir returns a non-empty String.
puts Dir.tmpdir.is_a?(String)
puts !Dir.tmpdir.empty?

# mktmpdir without a block: returns a newly-created directory path.
d = Dir.mktmpdir
begin
  puts d.is_a?(String)
  puts Dir.exist?(d)
  # Path includes date and pid.
  puts d.include?(Time.now.strftime("%Y%m%d"))
  puts d.include?(Process.pid.to_s)
ensure
  Dir.rmdir(d) if d && Dir.exist?(d)
end

# mktmpdir with a prefix string.
d = Dir.mktmpdir("myapp-")
begin
  puts File.basename(d).start_with?("myapp-")
ensure
  Dir.rmdir(d) if d && Dir.exist?(d)
end

# mktmpdir with [prefix, suffix] array.
d = Dir.mktmpdir(["foo", "bar"])
begin
  base = File.basename(d)
  puts base.start_with?("foo")
  puts base.end_with?("bar")
ensure
  Dir.rmdir(d) if d && Dir.exist?(d)
end

# mktmpdir with a block: yields the path, cleans up after.
result = Dir.mktmpdir do |path|
  puts path.is_a?(String)
  puts Dir.exist?(path)
  :done
end
puts result == :done
puts !Dir.exist?(Dir.tmpdir + "/d" + Time.now.strftime("%Y%m%d"))  # cleanup happened

# mktmpdir with parent_dir argument.
parent = Dir.mktmpdir
begin
  d = Dir.mktmpdir(nil, parent)
  begin
    puts File.dirname(d) == parent
  ensure
    Dir.rmdir(d) if Dir.exist?(d)
  end
ensure
  Dir.rmdir(parent) if Dir.exist?(parent)
end
