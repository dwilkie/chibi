require 'spec_helper'

describe PhoneCall do

  let(:user) { build(:user) }
  let(:new_phone_call) { build(:phone_call, :user => user) }

  describe "factory" do
    it "should be valid" do
      new_phone_call.should be_valid
    end
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { new_phone_call }
  end

end
