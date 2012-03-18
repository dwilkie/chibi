module AuthenticationHelpers
  private

  def authentication_params(resource)
    authentication_key = "HTTP_BASIC_AUTH_#{resource.to_s.upcase}"
    {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV["#{authentication_key}_USER"], ENV["#{authentication_key}_PASSWORD"]
    )}
  end
end
