# OpenSSL::PKey::EC -- elliptic-curve keys, in the shape #4221 settled on:
# CRuby's names where CRuby has a spelling, raw bytes where CRuby would hand
# back a BN or an EC::Point.
#
# So `EC.generate("prime256v1")` and `key.dh_compute_key(peer)` are the names
# a CRuby program already writes, but a key's halves are Strings --
# `private_key_bytes` is the scalar, `public_key_bytes` is the X9.62
# uncompressed point, 0x04 || X || Y -- and dh_compute_key takes the peer's
# bytes rather than a Point built out of a BN. `OpenSSL::BN`, `EC::Group` and
# `EC::Point` are not here, and a program that builds one fails at COMPILE
# time the way the rest of this package's gaps do.
#
# That is a real subset, and it is a deliberate one: those three classes exist
# in CRuby to express things this runtime has no other use for, and every
# protocol that names raw EC keys -- RFC 8291 Web Push, JWK's x/y halves,
# WebAuthn, ES256 -- names them as the byte strings above. A program that
# reaches for EC::Point is already doing protocol work that has to know the
# encoding anyway.
#
# A key is its bytes, so nothing on the C side outlives a call: there is no
# handle to release and no slot to run out of, unlike the connection table
# SSLSocket holds. An abandoned key costs nothing.
module OpenSSL
  module PKey
    class PKeyError < OpenSSLError
    end

    class ECError < PKeyError
    end

    class EC
      # The curve is carried, not inferred: the byte lengths of both halves
      # follow from it, and a key whose curve is implicit has to be guessed at
      # from a length the moment two curves are in play.
      attr_reader :curve
      attr_reader :private_key_bytes
      attr_reader :public_key_bytes

      # CRuby's spelling, and CRuby's argument: the curve's name, "prime256v1"
      # for P-256. Whatever OBJ_txt2nid resolves works; anything else raises.
      def self.generate(curve)
        priv = Native.ec_generate(curve)
        raise ECError, Native.last_error if priv.empty?
        new(curve, priv)
      end

      # No CRuby spelling: CRuby reads a key from DER or PEM, and this package
      # parses neither. The bytes are what a protocol stores -- a VAPID
      # application server key is exactly this scalar, base64url'd.
      def self.from_private_bytes(curve, bytes)
        new(curve, bytes)
      end

      def initialize(curve, private_key_bytes)
        @curve = curve
        @private_key_bytes = private_key_bytes
        @public_key_bytes = Native.ec_public_bytes(curve, private_key_bytes)
        raise ECError, Native.last_error if @public_key_bytes.empty?
      end

      # CRuby's name; CRuby takes an EC::Point and this takes the same point's
      # uncompressed bytes. The answer is identical either way: the X
      # coordinate of the product, field-width, which is what CRuby returns
      # when no KDF is asked for.
      #
      # A peer key that is not a point on this curve raises rather than
      # answering: an ECDH against an off-curve point leaks the private scalar
      # to whoever chose it.
      def dh_compute_key(peer_public_bytes)
        secret = Native.ec_dh(@curve, @private_key_bytes, peer_public_bytes)
        raise ECError, Native.last_error if secret.empty?
        secret
      end
    end
  end
end
