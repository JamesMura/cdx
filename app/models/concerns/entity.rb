module Entity
  extend ActiveSupport::Concern

  included do
    serialize :custom_fields, Hash
    serialize :indexed_fields, Hash

    after_initialize do
      self.custom_fields  ||= {}
      self.indexed_fields ||= {}
    end

    before_save :encrypt_sensitive_data
  end

  attr_writer :plain_sensitive_data

  def plain_sensitive_data
    @plain_sensitive_data ||= Oj.load(MessageEncryption.decrypt(sensitive_data)) || {}
  end

  def merge(entity)
    self.plain_sensitive_data.deep_merge_not_nil!(entity.plain_sensitive_data)
    self.custom_fields.deep_merge_not_nil!(entity.custom_fields)
    self.indexed_fields.deep_merge_not_nil!(entity.indexed_fields)

    self
  end

  def empty_entity?
    self.plain_sensitive_data.blank? &&
      self.indexed_fields.blank? &&
      self.custom_fields.blank?
  end

private

  def encrypt_sensitive_data
    self.sensitive_data = MessageEncryption.encrypt Oj.dump(plain_sensitive_data)
    self
  end
end