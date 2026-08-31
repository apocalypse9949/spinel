# OpenSSL::Cipher -- CRuby's stateful object, over stateless C.
#
# The object a program writes is CRuby's, because that is what applications
# really write:
#
#   c = OpenSSL::Cipher.new("aes-128-gcm")
#   c.encrypt; c.key = k; c.iv = n; c.auth_data = ad
#   ct = c.update(plaintext) + c.final
#   tag = c.auth_tag
#
# What is underneath is not CRuby's. The key, iv, aad and the data handed to
# #update are held here as ordinary ivars, and the C is called exactly once,
# at #final, when every input exists at the same moment (#4221). So nothing on
# the C side survives a call: there is no EVP context to free, no handle into
# a table, and no slot to run out of. A Cipher abandoned before #final -- an
# exception mid-stream, or a decrypt that raises on a bad tag from attacker
# input -- costs nothing, exactly like an abandoned EC key. A handle table
# would have needed a free protocol, and CRuby's Cipher protocol has no #close
# to hang one on.
#
# THE SUBSET THAT BUYS: this buffers rather than streams. A caller running a
# large file through a cipher holds it in memory, where CRuby would emit
# ciphertext as it went. GCM cannot answer its tag before #final in any case,
# so what is lost is streaming of the plaintext, not of the authentication --
# and #update answers "" with #final answering the whole result, which leaves
# the `update(x) + final` idiom returning exactly what CRuby returns.
#
# THE ALGORITHM SET IS aes-128-gcm AND aes-256-gcm, and any other name raises.
# Cipher.new's argument is an algorithm chosen by a runtime string, which
# openssl/digest.rb refuses for Digest -- "an algorithm chosen by a runtime
# string cannot resolve to a C function at compile time". The two are the same
# rule seen from both sides: EVP_get_cipherbyname is ONE C entry point that
# resolves the whole family, where sp_crypto's digests are one C function per
# algorithm. That is also why the set is a list rather than whatever EVP
# knows: a mode nothing here has run against vectors must not start working by
# accident. Widen it when something real needs a mode, with vectors.
module OpenSSL
  class CipherError < OpenSSLError
  end

  class Cipher
    # name => [key bytes, iv bytes]. GCM's 12-byte IV is the one every
    # protocol that names AES-GCM uses; another length is accepted, since GCM
    # defines them, but this is what #random_iv answers.
    CIPHERS = {
      "aes-128-gcm" => [16, 12],
      "aes-256-gcm" => [32, 12],
    }

    attr_reader :name

    def initialize(name)
      @name = name.to_s.downcase
      unless CIPHERS.key?(@name)
        raise CipherError,
              "unsupported cipher: #{name} (this package has #{CIPHERS.keys.join(", ")})"
      end
      @encrypting = true
      @key = ""
      @iv = ""
      @auth_data = ""
      @parts = []
      @auth_tag = ""
      @expected_tag = ""
      @done = false
    end

    # CRuby returns self from both, so `c.encrypt; ...` and `c.encrypt.key = k`
    # both work.
    def encrypt
      @encrypting = true
      self
    end

    def decrypt
      @encrypting = false
      self
    end

    def key_len = CIPHERS[@name][0]
    def iv_len  = CIPHERS[@name][1]

    def key=(k)
      unless k.bytesize == key_len
        raise CipherError, "key must be #{key_len} bytes for #{@name}"
      end
      @key = k
    end

    def iv=(v)
      raise CipherError, "iv must not be empty" if v.empty?
      @iv = v
    end

    # Covered by the tag, absent from the output.
    def auth_data=(a)
      @auth_data = a
    end

    # The tag to check, on the decrypt side. CRuby takes it before #final,
    # because #final is what verifies it.
    def auth_tag=(t)
      unless t.bytesize == 16
        raise CipherError, "auth tag must be 16 bytes"
      end
      @expected_tag = t
    end

    def random_key
      self.key = Crypto.random_bin(key_len)
      @key
    end

    def random_iv
      self.iv = Crypto.random_bin(iv_len)
      @iv
    end

    # Buffers. The answer is "" rather than the ciphertext so far, which is the
    # one place this diverges from CRuby's object -- see the header. The total
    # is unchanged, so `update(x) + final` is byte-identical either way.
    def update(data)
      raise CipherError, "cipher already finished" if @done
      @parts << data
      ""
    end

    # The whole operation, in one C call.
    def final
      raise CipherError, "cipher already finished" if @done
      raise CipherError, "key not set" if @key.empty?
      raise CipherError, "iv not set" if @iv.empty?
      @done = true
      data = @parts.join

      if @encrypting
        # Encrypt needs no status byte: the answer always carries a 16-byte
        # tag, so empty is unambiguously a failure.
        out = Native.aes_gcm_encrypt(@name, @key, @iv, @auth_data, data)
        raise CipherError, reason("AES-GCM encrypt failed") if out.empty?
        # ciphertext || tag: the C returns both in one value, and the tag is
        # always the last 16 bytes.
        @auth_tag = out.byteslice(out.bytesize - 16, 16)
        out.byteslice(0, out.bytesize - 16)
      else
        if @expected_tag.empty?
          raise CipherError, "auth_tag must be set before final on a decrypt"
        end
        out = Native.aes_gcm_decrypt(@name, @key, @iv, @auth_data, data, @expected_tag)
        # The verdict is the answer's own first byte, not a second call: an
        # empty string is a legitimate plaintext, so it cannot also mean
        # "forged", and an out-of-band verdict can be read after another
        # thread has overwritten it. last_error is only the wording.
        raise CipherError, reason("AES-GCM decrypt failed") if out.empty?
        out.byteslice(1, out.bytesize - 1)
      end
    end

    # Available after #final on the encrypt side, as in CRuby.
    def auth_tag
      raise CipherError, "auth_tag is not available until final" unless @done
      @auth_tag
    end

    private

    # last_error is per-thread, so this is the caller's own reason; it is the
    # wording of a failure the return value has already established, never the
    # test for whether one happened.
    def reason(fallback)
      err = Native.last_error
      err.empty? ? fallback : err
    end
  end
end
