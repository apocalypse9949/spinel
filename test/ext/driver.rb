# Drives the generated CRuby extension (ext-cruby-test); output pinned in
# expected_cruby.
$LOAD_PATH.unshift(File.dirname(__FILE__))
require "extk"
p ExtKernel.triple(5)
p ExtKernel.shout("hey")
p ExtKernel.total([1, 2, 3])
begin
  ExtKernel.must_pos(-2)
rescue ArgumentError => e
  puts "ArgumentError: #{e.message}"
end
begin
  ExtKernel.triple("x")
rescue TypeError
  puts "TypeError"
end
p ExtKernel.must_pos(6)
# NOTE: TOPLEVEL_NOTE deliberately absent -- the kernel's toplevel runs on
# the SPINEL side at init; nothing but the entry methods exists on the host.
