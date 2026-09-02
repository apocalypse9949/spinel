# Spinel bundled `tmpdir` -- a carried-C spin package (Path B).
#
# Dir.tmpdir and Dir.mktmpdir live in this package's C (sp_tmpdir.c,
# linked only when `require "tmpdir"` appears). The block form and
# the Dir.mktmpdir default-parent fallback are plain Ruby.
module TmpdirPackage
  native_lib "tmpdir"
  native_obj "packages/tmpdir/sp_tmpdir.o"
  native_func :Dir_tmpdir,      [],         :string, "sp_Dir_tmpdir"
  native_func :Dir_mktmpdir,    [:string],  :string, "sp_Dir_mktmpdir"
  native_func :Dir_mktmpdir_pp, [:string, :string], :string, "sp_Dir_mktmpdir_pp"
end

# Plain Ruby surface on top of the C binding. Dir is a class in spinel
# (not a module), so reopen it directly and add the singleton methods.
class Dir
  def self.tmpdir
    TmpdirPackage.Dir_tmpdir
  end

  def self.mktmpdir(prefix_suffix = nil, parent_dir = nil)
    prefix = ""
    if prefix_suffix
      s = prefix_suffix.to_s
      # CRuby: the prefix is the part of the template before the trailing
      # X's. For "dXXXXX" the prefix is "d". Most callers pass a static
      # prefix like "myapp-", so just use the whole string.
      prefix = s.sub(/X+\z/, "")
    end
    path = if parent_dir
      TmpdirPackage.Dir_mktmpdir_pp(prefix, parent_dir.to_s)
    else
      TmpdirPackage.Dir_mktmpdir(prefix)
    end
    if block_given?
      begin
        yield path
      ensure
        # Best-effort cleanup. Only handles empty directories; callers
        # with files inside should clean up themselves.
        Dir.delete(path) if Dir.exist?(path) && Dir.empty?(path)
      end
    else
      path
    end
  end
end

