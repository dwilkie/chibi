require 'rails_helper'

describe Hash do
  describe "#underscorify_keys" do
    let(:hash) { { "HelloWorld" => "hello_world" } }

    it "should underscore the keys" do
      expect(hash.underscorify_keys).to have_key(:hello_world)
    end
  end

  describe "#integerify!" do
    let(:hash) { { "1" => "2" } }

    it "should make the keys and values integers" do
      expect(hash.integerify[1]).to eq(2)
    end
  end
end
