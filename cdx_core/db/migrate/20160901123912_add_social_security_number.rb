class AddSocialSecurityNumber < ActiveRecord::Migration
  def change
    add_column :patients, :social_security_code, :string, default: ''
  end
end
