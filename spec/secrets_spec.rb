require 'rails_helper'

describe "'config/secrets.yml'" do
  it "should not contain any missing keys" do
    all_secrets = YAML.load_file(Rails.root + "config/secrets.yml") || {}
    production_secrets = all_secrets["production"]
    test_secrets = all_secrets["test"]
    test_secrets.each do |test_secret_key, test_secret|
      expect(production_secrets).to have_key(test_secret_key)
    end

    expect(production_secrets.size).to eq(test_secrets.size)

    production_secrets.each do |production_secret_key, production_secret|
      expect(production_secret).to match(/\<\%\=\s*ENV\[\"#{production_secret_key.upcase}\"\]\s*\%\>/)
    end
  end
end
