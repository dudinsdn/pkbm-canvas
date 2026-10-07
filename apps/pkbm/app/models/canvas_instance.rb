class CanvasInstance < ActiveRecord::Base
  def credentials
    self.class.encryptor.decrypt_and_verify(credentials_encrypted, purpose: "canvas_credentials")
  end
  def credentials=(value)
    self.credentials_encrypted = self.class.encryptor.encrypt_and_sign(value, purpose: "canvas_credentials")
  end
  def self.encryptor
    key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key("pkbm_canvas_credentials", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end
end
