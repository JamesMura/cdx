require 'spec_helper'

describe Patient do
  describe 'associations' do
    it { should validate_length_of(:social_security_code) }
  end
end
