/* sp_tmpdir.c -- Dir.tmpdir / Dir.mktmpdir for the `tmpdir` spin package.

   CRuby-compatible surface:
   - Dir.tmpdir -> String, the system temp dir (TMPDIR or "/tmp")
   - Dir.mktmpdir(prefix=NULL) -> String
   - Dir.mktmpdir(prefix=NULL, parent=NULL) -> String
     Creates a uniquely-named directory under parent (or Dir.tmpdir if
     parent is NULL), optionally prefixed by `prefix`. Returns the path.
     Raises Errno::EEXIST after TMPDIR_RETRIES (10000) failed attempts.

   The block form is plain Ruby in tmpdir.rb; the native side just does
   the create-and-return. */
#include "spinel/runtime.h"
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

#define TMPDIR_RETRIES 10000

/* Create a uniquely-named directory and return its path. The path is
   "parent/dXXXXX" where XXXXX is 5 random lowercase letters. */
static const char *tmpdir_mkdtemp(const char *prefix, const char *parent) {
  size_t pre_len = prefix ? strlen(prefix) : 0;
  size_t par_len = strlen(parent);
  /* path = parent + "/" + prefix + "dXXXXX" + NUL. Stack-allocate: even
     the longest practical parent + prefix fits in 512 bytes. */
  char path[512];
  if (par_len + 1 + pre_len + 7 > sizeof(path))
    sp_raise_cls("ArgumentError", "tmpdir path too long");

  /* Seed: time + pid + counter. */
  unsigned int seed = (unsigned int)(time(NULL) ^ (getpid() << 16));

  for (int i = 0; i < TMPDIR_RETRIES; i++) {
    memcpy(path, parent, par_len);
    path[par_len] = '/';
    if (pre_len) memcpy(path + par_len + 1, prefix, pre_len);
    char *suf = path + par_len + 1 + pre_len;
    suf[0] = 'd';
    unsigned int s = seed + i;
    for (int j = 1; j < 6; j++) {
      suf[j] = 'a' + (s % 26);
      s /= 26;
    }
    suf[6] = '\0';

    if (mkdir(path, 0700) == 0) {
      size_t n = par_len + 1 + pre_len + 6;
      char *r = sp_str_alloc_raw(n + 1);
      memcpy(r, path, n);
      r[n] = '\0';
      sp_str_set_len(r, n);
      return r;
    }
    if (errno != EEXIST) {
      int saved = errno;
      sp_raise_cls("Errno::ENOENT", strerror(saved));
    }
  }
  sp_raise_cls("Errno::EEXIST", "too many temporary directory retries");
  return sp_str_empty;  /* unreachable */
}

const char *sp_Dir_tmpdir(void) {
  const char *env = getenv("TMPDIR");
  if (env && *env) {
    size_t n = strlen(env);
    char *r = sp_str_alloc_raw(n + 1);
    memcpy(r, env, n);
    r[n] = '\0';
    sp_str_set_len(r, n);
    return r;
  }
  /* "/tmp" */
  char *r = sp_str_alloc_raw(5);
  memcpy(r, "/tmp", 4);
  r[4] = '\0';
  sp_str_set_len(r, 4);
  return r;
}

const char *sp_Dir_mktmpdir(const char *prefix) {
  const char *parent = sp_Dir_tmpdir();
  return tmpdir_mkdtemp(prefix, parent);
}

const char *sp_Dir_mktmpdir_pp(const char *prefix, const char *parent) {
  return tmpdir_mkdtemp(prefix, parent);
}
