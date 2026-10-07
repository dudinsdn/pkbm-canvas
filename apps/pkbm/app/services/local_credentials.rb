require "openssl"
require "securerandom"
class LocalCredentials
  ITERATIONS = 210_000
  def self.digest(password)
    raise ArgumentError, "Password minimal 12 karakter" if password.to_s.length < 12 || password.to_s.bytesize > 1024
    salt = SecureRandom.hex(16)
    value = OpenSSL::KDF.pbkdf2_hmac(password, salt: salt, iterations: ITERATIONS, length: 32, hash: "SHA256").unpack1("H*")
    "pbkdf2_sha256$#{ITERATIONS}$#{salt}$#{value}"
  end

  def self.valid?(password, digest)
    return false if password.to_s.bytesize > 1024
    kind, rounds, salt, wanted = digest.to_s.split("$")
    return false unless kind == "pbkdf2_sha256" && rounds.to_i == ITERATIONS && wanted.present?
    actual = OpenSSL::KDF.pbkdf2_hmac(password.to_s, salt: salt, iterations: rounds.to_i, length: 32, hash: "SHA256").unpack1("H*")
    ActiveSupport::SecurityUtils.secure_compare(actual, wanted)
  end
end
