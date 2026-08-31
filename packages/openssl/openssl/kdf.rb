# OpenSSL::KDF.hkdf -- HKDF (RFC 5869), CRuby's spelling and CRuby's keywords.
#
# No C: HKDF is HMAC over raw bytes, extract then expand, and the raw HMAC
# spelling landed beside this file. Writing it in Ruby keeps it out of the
# OPENSSL_AVAILABLE gate -- a program that reaches HKDF through this package
# gets it whether or not the build found libcrypto's headers, the same way
# OpenSSL::Digest works.
module OpenSSL
  module KDF
    class KDFError < OpenSSLError
    end

    # Extract-then-expand, in one call as CRuby has it. `salt` is optional in
    # the RFC and defaults to a string of zeros the length of the hash; CRuby
    # requires the keyword, so an explicit "" gets the RFC's default here.
    #
    # The length ceiling is the RFC's: expand emits 255 hash-lengths at most,
    # because the counter it appends is one octet.
    def self.hkdf(ikm, salt:, info:, length:, hash:)
      algo = hash.to_s.upcase
      hlen = case algo
             when "SHA256" then 32
             when "SHA1"   then 20
             else raise Digest::DigestError, "unsupported digest algorithm: #{hash}"
             end
      raise KDFError, "length must be positive" if length <= 0
      raise KDFError, "length exceeds #{255 * hlen} for #{algo}" if length > 255 * hlen

      prk = HMAC.digest(algo, salt.empty? ? "\0" * hlen : salt, ikm)

      blocks = []
      block = ""
      have = 0
      counter = 1
      while have < length
        block = HMAC.digest(algo, prk, block + info + counter.chr)
        blocks << block
        have += block.bytesize
        counter += 1
      end
      # ASCII-8BIT, as CRuby answers: this is keying material, and a caller
      # comparing it against bytes off a wire needs the tag to agree.
      blocks.join.byteslice(0, length).b
    end
  end
end
