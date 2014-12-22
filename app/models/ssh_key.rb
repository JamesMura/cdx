class SshKey < ActiveRecord::Base

  belongs_to :device

  validates_presence_of :public_key
  validate :validate_public_key

  def validate_public_key
    to_client.validate! unless public_key.blank?
  rescue
    errors.add(:public_key, "Key #{public_key.truncate(10)} is invalid")
  end

  def to_client
    CDXSync::Client.new(device.secret_key, public_key)
  end

  class << self
    def regenerate_authorized_keys!
      CDXSync::AuthorizedKeys.new.write! clients, CDXSync::SyncDirectory.new
    end

    def clients
      all.map(&:to_client)
    end
  end

end
