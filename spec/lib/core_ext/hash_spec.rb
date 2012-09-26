require 'spec_helper'

describe Hash do
  describe "#underscorify_keys!" do
    let(:hash) { { "HelloWorld" => "hello_world" } }

    it "should underscore the keys" do
      hash.underscorify_keys!
      hash.should have_key(:hello_world)
    end
  end

  describe "#integerify_keys!" do
    let(:hash) { { "1" => "hello_world" } }

    it "should make the keys integers" do
      hash.integerify_keys!
      hash.should have_key(1)
    end
  end
end
