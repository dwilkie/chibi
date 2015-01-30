module AdminHelpers
  def authorize
    page.driver.browser.basic_authorize(
      Rails.application.secrets[:http_basic_auth_admin_user],
      Rails.application.secrets[:http_basic_auth_admin_password]
    )
  end
end
