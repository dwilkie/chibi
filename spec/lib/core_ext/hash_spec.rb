require 'rails_helper'

describe Hash do
  describe "#underscorify_keys!" do
    let(:hash) { { "HelloWorld" => "hello_world" } }

    it "should underscore the keys" do
      hash.underscorify_keys!
      expect(hash).to have_key(:hello_world)
    end
  end

  describe "#integerify!" do
    let(:hash) { { "1" => "1" } }

    it "should make the keys and values integers" do
      hash.integerify!
      expect(hash[1]).to eq(1)
    end
  end
end
