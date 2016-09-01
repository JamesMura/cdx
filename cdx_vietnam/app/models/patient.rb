class Patient < ActiveRecord::Base
  include PatientConcern

  validates :social_security_code, length: { in: 9..15 }
end
