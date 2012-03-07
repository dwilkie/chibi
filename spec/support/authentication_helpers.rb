module AuthenticationHelpers
  private

  def authentication_params
    {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV["HTTP_BASIC_AUTH_USER"], ENV["HTTP_BASIC_AUTH_PASSWORD"]
    )}
  end
end
