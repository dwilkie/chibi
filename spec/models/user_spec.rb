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

  it "should not be valid without a mobile number" do
    new_user.mobile_number = nil
    new_user.should_not be_valid
  end

  it "should not be valid without a location" do
    new_user.location = nil
    new_user.should_not be_valid
  end

  context "factory" do
    it "should be valid" do
      new_user.should be_valid
    end
  end

  describe ".matches", :focus do

    # Match Explanations
    # see spec/factories.rb for where users are defined

    # Alex and Jamie:
    # Alex and Jamie have not specified their gender or what gender they are looking for.
    # We don't want to initiate a chat with other users who have already specified this info
    # because the other user may not be interesed in the gender of Jamie or Alex.
    # There are no other users in this situation so they only match with each other.

    # Chamroune and Pauline:
    # Chamroune is looking for a female, but his/her gender is unknown. Similarly to Alex and Jamie,
    # we don't want to just match Chamroune with any female, incase that female is not looking for
    # the gender of Chamroune. Pauline on the other hand is a female,
    # but she has not yet specified what gender she is looking for.
    # In this match Chamroune will be happy because he will be chatting with a female and Pauline can't complain
    # if she is not looking for Chamroune's gender because she hasn't specified what she's looking for.
    # Furthermore, other users who have specified their gender should not be matched with Pauline incase,
    # pauline isn't interested in their gender.

    # Nok with Michael:
    # Nok is a female looking for a male. Dave is a male, looking for a female, but she can't be matched him
    # because Dave is in Cambodia and Nok is in Thailand. Hanh and View are both guys in Thailand
    # but they are gay so she also can't be matched with either of them. Michael is a guy from Thailand
    # who looking for either a guy or a girl so Michael matches with Nok.

    # Dave with Mara
    # Dave is in Cambodia looking for a female. Harriet, Eva and Mara are all females in Cambodia however
    # Harriet and Eva are lesbians, while Mara is looking for either a girl or a guy so
    # Mara matches with Dave.

    # Harriet and Eva with Mara
    # Harriet is currently already chatting with Eva both of them could only be matched with Mara.
    # Thes matches should however never take place because they're in a chat session so they can't be searching.

    # Hanh with Michael and View
    # All three guys live in Chiang Mai, Thailand. Michael is bi and View is gay so either are a match.
    # Michael is only one year older than Hanh, whereas View is two years younger, so Michael is matched first.

    # View with Hanh
    # View has previously chatted with Michael so only Hanh is matched

    # Mara with Dave
    # Mara is bi, so she could match with either, Dave, Harriet or Eva who are all in Cambodia.
    # However Eva and Harriet are currently chatting so Dave is her match.

    # Michael with Hanh and Nok
    # Michael has previously chatted with View which leaves Nok and Hanh.
    # Nok hasn't specified her age yet and Hanh is only one year younger so Michael is matched with
    # Hanh before Nok.

    USER_MATCHES = {
      :alex => [:jamie],
      :jamie => [:alex],
      :chamroune => [:pauline],
      :pauline => [:chamroune],
      :nok => [:michael],
      :dave => [:mara],
      :harriet => [:mara],
      :eva => [:mara],
      :hanh => [:michael, :view],
      :view => [:hanh],
      :mara => [:dave],
      :michael => [:hanh, :nok]
    }

    USER_MATCHES.each do |user, matches|
      let(user) { create(user) }
    end

    def load_matches
      USER_MATCHES.each do |user, matches|
        send(user)
      end
      create(:active_chat, :user => eva, :friend => harriet)
      create(:chat, :user => michael, :friend => view)
    end

    it "should not include the person being matched" do
      subject.class.matches(user).should_not include(user)
    end

    context "given there are other users" do
      before do
        load_matches
      end

      it "should match the user with the best compatible match", :focus do
        USER_MATCHES.each do |user, matches|
          subject.class.matches(send(user)).map { |match| match.name.to_sym }.should == matches
        end
      end
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
