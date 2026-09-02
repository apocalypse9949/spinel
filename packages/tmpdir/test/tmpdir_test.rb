require "tmpdir"

# tmpdir: Dir.tmpdir returns a non-empty String (TMPDIR or "/tmp").
puts Dir.tmpdir.is_a?(String)
puts !Dir.tmpdir.empty?

# mktmpdir without a block returns a newly-created directory path.
d = Dir.mktmpdir
begin
  puts d.is_a?(String)
  puts Dir.exist?(d)
ensure
  Dir.rmdir(d) if d && Dir.exist?(d)
end

# mktmpdir with a prefix.
d = Dir.mktmpdir("myapp-")
begin
  puts File.basename(d).start_with?("myapp-")
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
