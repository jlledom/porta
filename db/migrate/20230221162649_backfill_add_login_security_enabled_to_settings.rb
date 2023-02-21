class BackfillAddLoginSecurityEnabledToSettings < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Settings.unscoped.in_batches do |relation|
      relation.update_all login_security_enabled: false
      sleep(0.01)
    end
  end
end
