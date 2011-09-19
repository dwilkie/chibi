require 'spec_helper'

# stub out solr with mocks here
# https://github.com/pivotal/sunspot_matchers

describe User do
  let(:sok) {
    create(:registered_male_user, :location => "Siem Reap")
  }

  let(:mara) { create(:registered_female_user) }

  let(:guys_looking_for_girls) do
    create_list(:guy_looking_for_girls, 4)
  end

  describe ".matches" do
    it "should not include the person being matched" do
      subject.class.matches(sok).should_not include(sok)
    end

    context "with less than 5 registered users" do
      before do
        guys_looking_for_girls
      end

      it "should return all the registered users" do
        subject.class.matches(sok).size.should == 4
      end

      it "should only include registered users" do
        subject.class.matches(sok).each do |match|
          match.should be_ready
        end
      end
    end
  end
end

