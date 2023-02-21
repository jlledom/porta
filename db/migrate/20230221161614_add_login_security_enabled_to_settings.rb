class AddLoginSecurityEnabledToSettings < ActiveRecord::Migration[5.2]
  def up
    add_column :settings, :login_security_enabled, :boolean
    change_column_default :settings, :login_security_enabled, false
  end

  def down
    remove_column :settings, :login_security_enabled
  end
end
