module AuthenticationHelpers
  private

  def authentication_params(resource)
    authentication_key = "http_basic_auth_#{resource}"
    {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
      Rails.application.secrets[:"#{authentication_key}_user"],
      Rails.application.secrets[:"#{authentication_key}_password"]
    )}
  end
end
