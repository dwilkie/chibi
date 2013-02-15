module AdminHelpers
  def authorize
    page.driver.browser.basic_authorize(
      ENV["HTTP_BASIC_AUTH_ADMIN_USER"], ENV["HTTP_BASIC_AUTH_ADMIN_PASSWORD"]
    )
  end
end
