require 'spec_helper'

describe Hash do
  describe "#underscorify_keys!" do
    let(:hash) { { "HelloWorld" => "hello_world" } }

    it "should underscore the keys" do
      hash.underscorify_keys!
      hash.should have_key(:hello_world)
    end
  end

  describe "#integerify!" do
    let(:hash) { { "1" => "1" } }

    it "should make the keys and values integers" do
      hash.integerify!
      hash[1].should == 1
    end
  end
end
