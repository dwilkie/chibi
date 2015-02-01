module EnvHelpers
  def stub_env(key, value)
    allow(Rails.application.secrets).to receive(:[]).and_call_original
    allow(Rails.application.secrets).to receive(:[]).with(key.downcase.to_sym).and_return(value)
  end
end
