module AuthenticationHelpers
  private

  def authentication_params(type = nil)
    key_base = "HTTP_BASIC_AUTH"
    key_base << "_#{type.to_s.upcase}" if type
    {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV["#{key_base}_USER"], ENV["#{key_base}_PASSWORD"]
    )}
  end
end
