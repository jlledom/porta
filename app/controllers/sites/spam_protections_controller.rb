class Sites::SpamProtectionsController < Sites::BaseController
  sublayout 'sites/developer_portals'
  activate_menu :audience, :cms, :spam_protection

  before_action :find_settings

  def edit
  end

  def update
    if @settings.update_attributes(settings_params)
      flash[:notice] = 'Bot protection settings updated.'
      redirect_to edit_admin_site_spam_protection_url
    else
      flash[:error] = 'There were problems saving the settings.'
      render :action => 'edit'
    end
  end

  private

  def settings_params
    params.require(:settings).permit(:spam_protection_level)
  end

  def find_settings
    @settings = current_account.settings
  end

end
