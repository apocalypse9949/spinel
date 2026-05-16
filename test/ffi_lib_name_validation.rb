# Test that FFI lib names are validated.
module SQL
  ffi_lib "sqlite3"
end
puts "ok"
