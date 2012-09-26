require 'spec_helper'

describe Overview do
  describe "#new_users" do
    it "should return the overview of all new users" do
      User.should_receive(:overview_of_created)
      subject.new_users
    end
  end
end
