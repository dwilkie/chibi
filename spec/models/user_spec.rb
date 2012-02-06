require 'spec_helper'

describe User do

  let(:user) do
    create(:user)
  end

  let(:new_user) do
    build(:user)
  end

  let(:user_with_complete_profile) { build(:user_with_complete_profile) }

  it "should not be valid without a mobile number" do
    new_user.mobile_number = nil
    new_user.should_not be_valid
  end

  it "should not be valid without a screen name" do
    user.screen_name = nil
    user.should_not be_valid
  end

  it "should not be valid without a location" do
    new_user.location = nil
    new_user.should_not be_valid
  end

  it "should default to being online" do
    subject.should be_online
  end

  describe "factory" do
    it "should be valid" do
      new_user.should be_valid
    end
  end

  describe "associations" do
    describe "location" do
      before do
        user
      end

      it "should be autosaved" do
        user.location.city = "Melbourne"
        user.save
        user.location.reload.city.should == "Melbourne"
      end
    end
  end

  describe "callbacks" do
    it "should generate a screen name before validation on create" do
      new_user.screen_name.should be_nil
      new_user.valid?
      new_user.screen_name.should be_present
    end
  end

  describe ".matches" do

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

    # Joy with Con, Dave, Paul and Luke:
    # Joy is a straight female in Cambodia. Con, Dave and Luke are straight males also in Cambodia.
    # Dave is two years older than Joy, Con is 10 years older, Paul 12 years older and Luke is 2 years younger.
    # Even though Joy is closer in age to Dave, Con matches before Dave because Con has initiated more
    # chats and he is still just in the free age zone (up to 10 years older) where age difference doesn't really
    # matter. Paul has also initiated more chats than Dave but he is just outside the free age zone
    # and the age difference is starting to be a concern. In this case Dave matches higher even though he
    # has initiated less chats than Paul. If Paul intiates more chats however,
    # he can still overtake Dave, but the larger the age gap (over 10 years) the more chats you have to initiate
    # to keep in touch with the young ones. Luke has initiated more chats than Con, Dave and Paul
    # but he matches last because he is 2 years younger than Joy.
    # We are assuming that Joy being a female is looking for an older guy.

    # Dave with Mara and Joy
    # Dave is in Cambodia looking for a female. Harriet, Eva, Mara and Joy are all females in Cambodia however
    # Harriet and Eva are gay, so they are ruled out. Mara is bi and Joy is straight so both are matches.
    # Although Joy is closer in age to Dave than Mara, Mara matches first because she has initiated more chats.

    # Con with Joy
    # Joy and Mara both match, but Con has already chatted with Mara, so Joy is Con's match

    # Paul with Joy and Mara
    # Joy and Mara are both younger girls but fall outside of the free age zone. Joy is 12 years younger than
    # Paul while Mara is 14 years younger. Even though Mara has initiated more chats than Joy, Joy is still matched
    # before Mara. Mara would have to initiate 3 times as many chats as Joy for her to be match before Joy

    # Harriet and Eva with Mara
    # Harriet is currently already chatting with Eva both of them could only be matched with Mara.
    # These matches should however never take place because they're in a chat session so they can't be searching.

    # Hanh with Michael and View
    # All three guys live in Chiang Mai, Thailand. Michael is bi and View is gay so either are a match.
    # Both of them are in the free age zone, but michael has initiated more chats, so he is matched first

    # View with Hanh
    # View has previously chatted with Michael so only Hanh is matched

    # Mara with Luke, Dave and Paul
    # Mara is bi, so she could match with either, Dave, Con, Paul, Luke, Harriet or Eva who are all in Cambodia.
    # However Eva and Harriet are currently chatting and Mara has already chatted with Con, so that leaves
    # Dave, Luke and Paul. Luke and Dave are both within the free age zone so Luke matches before Dave,
    # because he has initiated more chats. Paul has also initiated more chats than Dave but he falls outside
    # the free age zone, so Dave is matched before him.

    # Michael with Hanh and Nok
    # Michael has previously chatted with View which leaves Nok and Hanh. Even though Nok hasn't specified
    # her age yet we give her the benifit of the doubt and assume she's in the free age zone.
    # Hanh has initiated more chat than Nok so he is matched first.

    USER_MATCHES = {
      :alex => [:jamie],
      :jamie => [:alex],
      :chamroune => [:pauline],
      :pauline => [:chamroune],
      :nok => [:michael],
      :joy => [:con, :dave, :paul, :luke],
      :dave => [:mara, :joy],
      :con => [:joy],
      :paul => [:joy, :mara],
      :luke => [:mara, :joy],
      :harriet => [:mara],
      :eva => [:mara],
      :hanh => [:michael, :view],
      :view => [:hanh],
      :mara => [:luke, :dave, :paul],
      :michael => [:hanh, :nok]
    }

    USER_MATCHES.each do |user, matches|
      let(user) { create(user) }
    end

    def load_matches
      USER_MATCHES.each do |user, matches|
        send(user)
      end
      create(:active_chat, :user => eva,        :friend => harriet)
      create(:chat,        :user => michael,    :friend => view)
      create(:chat,        :user => con,        :friend => mara)
      create(:chat,        :user => mara,       :friend => nok)
      create(:chat,        :user => hanh,       :friend => nok)
      create(:chat,        :user => luke,       :friend => nok)
      create(:chat,        :user => luke,       :friend => hanh)
      create(:chat,        :user => paul,       :friend => nok)
    end

    context "given there are other users" do
      before do
        load_matches
      end

      it "should match the user with the best compatible match" do
        USER_MATCHES.each do |user, matches|
          results = subject.class.matches(send(user))
          results.map { |match| match.name.to_sym }.should == matches
          results.each do |result|
            result.should_not be_readonly
          end
        end
      end
    end
  end

  describe "#profile_complete?" do
    it "should only be true if all the profile attributes are present" do
      user_with_complete_profile.should be_profile_complete

      ["name", "date_of_birth", "gender", "looking_for"].each do |attribute|
        reference_user = build(:user_with_complete_profile)
        reference_user.send("#{attribute}=", nil)
        reference_user.should_not be_profile_complete
      end

      user_with_complete_profile.location.city = nil
      user_with_complete_profile.should_not be_profile_complete
    end
  end

  describe "#missing_profile_attributes" do
    it "should return the missing attributes of the user" do
      subject.missing_profile_attributes.should == [:name, :date_of_birth, :city, :gender, :looking_for]
      user_with_complete_profile.missing_profile_attributes.should == []

      user_with_complete_profile.date_of_birth = nil
      user_with_complete_profile.missing_profile_attributes.should == [:date_of_birth]
    end
  end

  describe "#city" do
    it "should delegate to location" do
      subject.city.should be_nil
      user_with_complete_profile.city.should be_present
    end
  end

  describe "#locale" do
    it "should delegate to location" do
      subject.locale.should be_nil
      user.locale.should be_present
    end
  end

  describe "#female?" do
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

  describe "#hetrosexual?" do
    it "should be true only for straight males and straight females" do
      # unknown sexual preference
      subject.should_not be_hetrosexual

      # gay guy
      subject.gender = "m"
      subject.looking_for = "m"
      subject.should_not be_hetrosexual

      # bi guy
      subject.looking_for = "e"
      subject.should_not be_hetrosexual

      # straight guy
      subject.looking_for = "f"
      subject.should be_hetrosexual

      # gay girl
      subject.gender = "f"
      subject.looking_for = "f"
      subject.should_not be_hetrosexual

      # bi girl
      subject.looking_for = "e"
      subject.should_not be_hetrosexual

      # straight girl
      subject.looking_for = "m"
      subject.should be_hetrosexual
    end
  end

  describe "#male?" do
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

    context "nil" do
      before do
        subject.age = nil
      end

      it "should set the user' date of birth to nil" do
        subject.date_of_birth.should be_nil
      end
    end
  end

  describe "#currently_chatting?" do
    context "given the user is in an active chat session" do
      let(:active_chat) { create(:active_chat, :user => user) }
      before do
        active_chat
      end

      it "should be true" do
        user.should be_currently_chatting
      end
    end

    context "given the user is not in an active chat session" do
      it "should be false" do
        user.should_not be_currently_chatting
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
        subject.date_of_birth = 23.years.ago.utc.to_date
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

  describe "#screen_id" do
    context "the user has a name" do
      let(:user_with_name) { create(:user, :name => "sok", :id => 69) }

      it "should return a combination of the user's name and id" do
        user_with_name.screen_id.should == "sok69"
      end
    end

    context "the user has no name" do
      let(:user_without_name) { create(:user, :id => 88) }

      it "should return a combination of the screen name and id" do
        user_without_name.screen_id.should == "#{user_without_name.screen_name}88"
      end
    end
  end

  describe "#logout!" do
    it "should mark the user as offline" do
      user.logout!
      user.should_not be_online
    end
  end
end
