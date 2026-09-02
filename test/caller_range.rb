# Kernel#caller accepts an integer Range literal as a window.
# The Range is rewritten to the (start, len) form. Frame *content*
# is only populated in --debug builds (release returns []), so this
# checks the dispatch shape: caller(0..3) returns an Array, and the
# window is honored (length <= 4 for a 0..3 window).

frames = caller(0..3)
puts frames.is_a?(Array)
puts frames.length <= 4
