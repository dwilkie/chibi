require 'spec_helper'

# stub out solr with mocks here
# https://github.com/pivotal/sunspot_matchers

describe User do

  let(:user) do
    create(:user)
  end

  let(:new_user) do
    build(:user)
  end

  let(:user_with_complete_profile) do
    create(:user_with_complete_profile)
  end

  let(:sok) do
    create(:registered_male_user, :location => "Siem Reap")
  end

  let(:mara) do
    create(:registered_female_user)
  end

  let(:guys_looking_for_girls) do
    create_list(:guy_looking_for_girls, 4)
  end

  it "should not be valid without a mobile number" do
    new_user.mobile_number = nil
    user.should_not be_valid
  end

  context "factory" do
    it "factory should be valid" do
      new_user.should be_valid
    end
  end

  describe ".matches" do
    it "should not include the person being matched" do
      subject.class.matches(sok).should_not include(sok)
    end
  end

  describe "#profile_complete?" do
    context "has a complete profile" do
      it "should be true" do
        user_with_complete_profile.should be_profile_complete
      end
    end

    context "is missing their" do
      shared_examples_for "missing profile" do
        before do
          user_with_complete_profile.send("#{attribute}=", nil)
        end

        it "should not be true" do
          user_with_complete_profile.should_not be_profile_complete
        end
      end

      ["name", "date_of_birth", "location", "gender", "looking_for"].each do |attribute|
        context attribute do
          it_should_behave_like "missing profile" do
            let(:attribute) {attribute}
          end
        end
      end
    end
  end

  describe "female?" do
    context "gender is 'f'" do
      before do
        subject.gender = "f"
      end

      it "should be true" do
        subject.should be_female
      end
    end

    context "gender is 'm'" do
      before do
        subject.gender = "m"
      end

      it "should be false" do
        subject.should_not be_female
      end
    end

    context "gender is not set" do
      it "should be false" do
        subject.should_not be_female
      end
    end
  end

  describe "male?" do
    context "gender is 'm'" do
      before do
        subject.gender = "m"
      end

      it "should be true" do
        subject.should be_male
      end
    end

    context "gender is 'f'" do
      before do
        subject.gender = "f"
      end

      it "should be false" do
        subject.should_not be_male
      end
    end

    context "gender is not set" do
      it "should be false" do
        subject.should_not be_male
      end
    end
  end

  describe "#age=" do
    context "15" do
      before do
        Timecop.freeze(Time.now)
        subject.age = 15
      end

      after do
        Timecop.return
      end

      it "should set the user's date of birth to 15 years ago" do
        subject.date_of_birth.should == 15.years.ago.utc
      end
    end
  end

  describe "#age" do
    before do
      Timecop.freeze(Time.now)
    end

    after do
      Timecop.return
    end

    context "when user.age = 23" do
      before do
        subject.age = 23
      end

      it "should return 23" do
        subject.age.should == 23
      end
    end

    context "when the user's date of birth is 23 years ago" do
      before do
        subject.date_of_birth = 23.years.ago.utc
      end

      it "should return 23" do
        subject.age.should == 23
      end
    end

    context "when the user's date of birth is unknown" do

      it "should return nil" do
        subject.age.should be_nil
      end
    end

  end
end

