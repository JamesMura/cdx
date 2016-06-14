class Comment < ActiveRecord::Base
  include AutoUUID

  belongs_to :patient
  belongs_to :user

  validates_presence_of :description, :commented_on, :patient_id, :user_id

end
