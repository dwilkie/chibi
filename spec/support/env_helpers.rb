module EnvHelpers
  def stub_env(key, value)
    Rails.application.secrets.stub(:[]).and_call_original
    Rails.application.secrets.stub(:[]).with(key.downcase.to_sym).and_return(value)
  end
end
