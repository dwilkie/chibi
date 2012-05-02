require 'spec_helper'

describe User do
  include MobilePhoneHelpers
  include TranslationHelpers
  include MessagingHelpers
  include_context "replies"

  let(:user) { create(:user) }
  let(:new_user) { build(:user) }
  let(:cambodian) { build(:cambodian) }
  let(:friend) { create(:user) }
  let(:active_chat) { create(:active_chat, :user => user, :friend => friend) }
  let(:offline_user) { build(:offline_user) }
  let(:user_with_complete_profile) { build(:user_with_complete_profile) }

  it "should not be valid without a mobile number" do
    new_user.mobile_number = nil
    new_user.should_not be_valid
  end

  it "should not be valid with an invalid gender" do
    build(:user_with_invalid_gender).should_not be_valid
  end

  it "should not be valid with an invalid looking for preference" do
    build(:user_with_invalid_looking_for_preference).should_not be_valid
  end

  it "should not be valid with an invalid age" do
    build(:user_who_is_too_old).should_not be_valid
    build(:user_who_is_too_young).should_not be_valid
  end

  it "should not be valid with an invalid mobile number e.g. a short code" do
    build(:user_with_invalid_mobile_number).should_not be_valid
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

    context "when inititalizing a new user with a mobile number" do
      context "if a the user does not yet have a location" do
        it "should build a location based off the mobile number and assign it to itself" do
          with_users_from_different_countries do |country_code, prefix, country_name, factory_name|
            new_location = subject.class.new(:mobile_number => build(factory_name).mobile_number).location
            new_location.country_code.should == country_code
          end
        end
      end

      context "if the user is already persisted" do
        it "should not load the associated location to check if it exists" do
          # Otherwise it will load every location when displaying a list of users
          subject.class.any_instance.stub(:persisted?).and_return(true)
          subject.class.new.location.should be_nil
        end
      end

      context "if a user already has a location" do
        it "should not assign a new location to itself" do
          location = subject.class.new(
            :location => new_user.location, :mobile_number => new_user.mobile_number
          ).location

          location.should == new_user.location
        end
      end
    end
  end

  it_should_behave_like "filtering with chatable resources" do
    let(:resources) { [user, friend] }
  end

  describe ".filter_by" do
    it "should include the user's location to avoid loading it for each user" do
      subject.class.filter_by.includes_values.should == [:location]
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

    # Hanh with View and Michael
    # All three guys live in Chiang Mai, Thailand. Michael is bi and View is gay so either are a match.
    # Both of them are in the free age zone, but even though Michael has initiated more chats, View is matched
    # first because he was chatting more recently than Michael.

    # View with Nobody :(
    # View has previously chatted with Michael and Hanh is offline, so nobody is matched

    # Mara with Luke, Dave and Paul
    # Mara is bi, so she could match with either, Dave, Con, Paul, Luke, Harriet or Eva who are all in Cambodia.
    # However Eva and Harriet are currently chatting and Mara has already chatted with Con, so that leaves
    # Dave, Luke and Paul. Luke and Dave are both within the free age zone so Luke matches before Dave,
    # because he has initiated more chats. Paul has also initiated more chats than Dave but he falls outside
    # the free age zone, so Dave is matched before him.

    # Michael with Nok
    # Michael has previously chatted with View which leaves Nok and Hanh. Even though Nok hasn't specified
    # her age yet, we give her the benifit of the doubt and assume she's in the free age zone.
    # Hanh has initiated more chat than Nok so he would have been matched before Nok, but
    # Hanh is offline so he is eliminated from the results anyway.

    # Finally all of these users use mobile numbers which are not from a registered service provider
    # We don't want to match these users with users that have mobile numbers which are from
    # registered service providers. For example, say there are two registered service providers in Cambodia
    # Smart and Mobitel. If a Metfone user contacts the app through the test gateway
    # We don't want to match them with the Smart or Mobitel users, incase the test gateway is down or something.

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
      :hanh => [:view, :michael],
      :view => [],
      :mara => [:luke, :dave, :paul],
      :michael => [:nok]
    }

    USER_MATCHES.each do |user, matches|
      let(user) { create(user) }
    end

    def load_matches
      USER_MATCHES.each do |user, matches|
        send(user)
      end

      # create some chats
      create(:active_chat, :user => eva,        :friend => harriet)
      create(:chat,        :user => michael,    :friend => view)
      create(:chat,        :user => con,        :friend => mara)
      create(:chat,        :user => mara,       :friend => nok)
      create(:chat,        :user => hanh,       :friend => nok)
      create(:chat,        :user => luke,       :friend => nok)
      create(:chat,        :user => luke,       :friend => hanh)
      create(:chat,        :user => paul,       :friend => nok)

      # logout hanh
      hanh.logout!
    end

    context "given there are other users" do
      include_context "existing users"

      before do
        load_matches
        users_from_registered_service_providers
      end

      it "should match the user with the best compatible match" do
        USER_MATCHES.each do |user, matches|
          results = subject.class.matches(send(user))
          results.map { |match| match.name.try(:to_sym) || match.screen_name.to_sym }.should == matches
          results.each do |result|
            result.should_not be_readonly
          end
        end

        users_from_registered_service_providers.each do |user_from_registered_service_provider|
          results = subject.class.matches(user_from_registered_service_provider)
          results.should_not be_empty

          USER_MATCHES.each do |user_from_unregistered_service_provider, matches|
            results.should_not include(send(user_from_unregistered_service_provider))
          end
        end
      end
    end
  end

  describe "#update_profile" do

    KEYWORDS = {
      :en => {
        :boy => %w{m male},
        :could_mean_boy_or_boyfriend => %w{boy guy man},
        :girl => %w{f female},
        :could_mean_girl_or_girlfriend => %w{girl woman},
        :friend => %w{friend},
        :girlfriend => ["girlfriend", "gf", "friend girl", "girl friend"],
        :boyfriend => ["boyfriend", "bf", "friend boy", "boy friend"],
        :guy_looking_for_a_girl => ["guy looking for a hot girl sexy", "man seeking woman", "m seeking woman hot"],
        :girl_looking_for_a_guy => ["girl looking for a hot guy sporty", "woman seeking man", "f seeking guy hot"],
        :guy_looking_for_a_guy => ["male looking for a guy to have fun with", "guy seeking guy", "m seeking man"],
        :girl_looking_for_a_girl => ["f looking for a girl for relationship", "girl seeking girl", "f seeking woman"],
        :guy_looking_for_a_friend => ["m looking for a friend to hang out with", "guy seeking friend"],
        :girl_looking_for_a_friend => ["f looking for a friend to go shopping with", "girl seeking friend"],
        :guy_named_frank => ["im frank man", "i'm frank male", "i am frank guy", "my name is frank guy"],
        :girl_named_mara => ["im mara f", "i'm mara girl", "i am mara woman"],
        :"23_year_old" => ["im 23 years old", "23yo", "23 yo", "blah 23 badfa"],
        :phnom_penhian => ["from phnom penh"],
        :mara_25_pp_wants_friend => ["hi im mara 25 pp looking for friends"],
        :davo_28_guy_wants_bf => ["hi my name is davo male 28 looking for friends"],
        :sr_wants_girl => ["im in sr want to meet girl"],
        :kunthia_23_sr_girl_wants_boy => ["kunthia 23 girl sr want to meet boy"]
      },

      :kh => {
        :could_mean_boy_or_boyfriend => %w{pros bros},
        :could_mean_girl_or_girlfriend => %w{srey},
        :friend => %w{mit met},
        :girlfriend => ["met srey", "mit srey"],
        :boyfriend => ["met bros", "met pros", "mit bros", "mit pros"],
        :guy_looking_for_a_girl => ["bros sa-at jong mian srey sa-at", "khnom pros jab srey"],
        :girl_looking_for_a_guy => ["srey mao jong mian bros saat nas", "nhom srey jong mian pros hot"],
        :guy_looking_for_a_guy => ["nhom bros jong rok mit bros", "pros jong mian bros hot", "pros jong pros"],
        :girl_looking_for_a_girl => ["nhom srey jong mian bumak srey sa-at"],
        :guy_looking_for_a_friend => ["nhom pros jong rok met sabai", "bros jong rok mit leng sms", "pros rok met funny"],
        :girl_looking_for_a_friend => ["nhom srey jong rok met sabai", "srey jong rok mit leng sms", "srey rok met cute"],
        :guy_named_frank => ["kyom pros chmous frank", "chhmos frank jia bros", "nyom chhmous frank pros"],
        :girl_named_mara => ["kjom chmos mara srey", "chhmous mara srey", "chmos mara srey", "knhom chmous mara srey", "knyom chmos mara srey"],
        :"23_year_old" => ["kjom 23chnam", "23 chnam", "23", "dsakle 23dadsa"],
        :phnom_penhian => ["mok pi phnum penh" ,"mok pi pp"],
        :mara_25_pp_wants_friend => ["kjom chhmos mara 25 pp jong ban met"],
        :davo_28_guy_wants_friend => ["kjom chhmous davo bros 28 rok met srolanh ped doch knea"],
        :sr_wants_girl => ["khnom nov sr jong rok met srey"],
        :kunthia_23_sr_girl_wants_boy => ["kunthia 23 srey sr jong rok met bros"]
      }
    }

    def keywords(*keys)
      options = keys.extract_options!
      options[:user] ||= user
      options[:country_code] ||= options[:user].country_code
      all_keywords = []
      keys.each do |key|
        english_keywords = KEYWORDS[:en][key]
        localized_keywords = KEYWORDS.try(:[], options[:country_code].to_s.downcase.to_sym).try(:[], key)
        all_keywords |= localized_keywords.present? ? (english_keywords | localized_keywords) : english_keywords
      end
      all_keywords
    end

    def registration_examples(examples, options)
      examples.each do |info|
        assert_user_attributes(info, options)
      end
    end

    def assert_user_attributes(info, options)
      user_attributes = [:gender, :looking_for, :name, :age]

      user = options[:user] || build(:user)

      user.gender = options[:gender] ? options[:gender].to_s[0] : nil
      user.looking_for = options[:looking_for] ? options[:looking_for].to_s[0] : nil
      user.name = options[:name]
      user.age = options[:age]
      user.location.city = options[:city]

      user.save

      vcr_options = options[:vcr] || {}

      if vcr_options[:expect_results]
        match_requests_on = {}
        cassette = vcr_options[:cassette] ||= "results"
      else
        match_requests_on = {:match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]}
        cassette = vcr_options[:cassette] ||= "no_results"
      end

      cassette = info if cassette == :info

      Timecop.freeze(Time.now) do
        VCR.use_cassette(cassette, match_requests_on.merge(:erb => true)) do
          user.update_profile(info)
        end
      end

      options[:expected_gender] ? user.should(send("be_#{options[:expected_gender]}")) : user.gender.should(be_nil)
      options[:expected_looking_for] ? user.looking_for.should(eq(options[:expected_looking_for].to_s[0])) : user.looking_for.should(be_nil)
      options[:expected_city] ? user.location.city.should(eq(options[:expected_city])) : user.location.city.should(be_nil)
      options[:expected_name] ? user.name.should(eq(options[:expected_name])) : user.name.should(be_nil)
      options[:expected_age] ? user.age.should(eq(options[:expected_age])) : user.age.should(be_nil)
    end

    def assert_looking_for(options = {})
      # the info indicates the user is looking for a guy
      registration_examples(
        keywords(:could_mean_boy_or_boyfriend),
        { :expected_looking_for => :male }.merge(options)
      )

      # the info indicates the user is looking for a girl
      registration_examples(
        keywords(:could_mean_girl_or_girlfriend),
        { :expected_looking_for => :female }.merge(options)
      )

      # the info indicates the user is looking for a friend
      registration_examples(
        keywords(:friend),
        { :expected_looking_for => :either}.merge(options)
      )

      # can't determine what he/she is looking for from the info
      registration_examples(
        ["hello", "", "laskhdg"],
        { :expected_looking_for => options[:expected_looking_for_when_undetermined] }.merge(options)
      )
    end

    def assert_gender(options = {})
      # the info indicates a guy is texting
      registration_examples(
        keywords(:boy, :could_mean_boy_or_boyfriend),
        { :expected_gender => :male }.merge(options)
      )

      # the info indicates a girl is texting
      registration_examples(
        keywords(:girl, :could_mean_girl_or_girlfriend),
        { :expected_gender => :female }.merge(options)
      )
    end

    it "should save the record" do
      new_user.update_profile("")
      new_user.should be_persisted
    end

    context "for users with only one missing attribute" do
      it "should update their profile correctly" do

        registration_examples(
          ["Dave"],
          :user => user_with_complete_profile,
          :name => nil,
          :expected_name => "Dave",
          :gender => :male,
          :expected_gender => :male,
          :looking_for => :female,
          :expected_looking_for => :female,
          :age => 45,
          :expected_age => 45,
          :city => "Phnom Penh",
          :expected_city => "Phnom Penh"
        )
      end
    end

    context "for users with a missing gender or sexual preference" do
      it "should determine the missing details based off the info" do
        # a guy is texting
        assert_looking_for(
          :gender => :male,
          :expected_gender => :male
        )

        # a gay guy is texting
        assert_looking_for(
          :gender => :male,
          :expected_gender => :male,
          :looking_for => :male,
          :expected_looking_for_when_undetermined => :male
        )

        # a straight guy is texting
        assert_looking_for(
          :gender => :male,
          :expected_gender => :male,
          :looking_for => :female,
          :expected_looking_for_when_undetermined => :female
        )

        # a bi guy is texting
        assert_looking_for(
          :gender => :male,
          :expected_gender => :male,
          :looking_for => :either,
          :expected_looking_for_when_undetermined => :either
        )

        # a girl is texting
        assert_looking_for(
          :gender => :female,
          :expected_gender => :female,
        )

        # a gay girl is texting
        assert_looking_for(
          :gender => :female,
          :expected_gender => :female,
          :looking_for => :female,
          :expected_looking_for_when_undetermined => :female
        )

        # a straight girl is texting
        assert_looking_for(
          :gender => :female,
          :expected_gender => :female,
          :looking_for => :male,
          :expected_looking_for_when_undetermined => :male
        )

        # a bi girl is texting
        assert_looking_for(
          :gender => :female,
          :expected_gender => :female,
          :looking_for => :either,
          :expected_looking_for_when_undetermined => :either
        )

        # a user with a unknown gender looking for a guy is texting
        assert_gender(
          :looking_for => :male,
          :expected_looking_for => :male
        )

        # a user with a unknown gender looking for a girl is texting
        assert_gender(
          :looking_for => :female,
          :expected_looking_for => :female
        )

        # a user with a unknown gender looking for a friend is texting
        assert_gender(
          :looking_for => :either,
          :expected_looking_for => :either
        )
      end
    end

    context "for new users" do
      it "should try to determine as much as possible from the info provided" do
        # the info indicates a guy is texting
        registration_examples(
          keywords(:boy, :could_mean_boy_or_boyfriend),
          :expected_gender => :male
        )

        # the info indicates a girl is texting
        registration_examples(
          keywords(:girl, :could_mean_girl_or_girlfriend),
          :expected_gender => :female
        )

        # the info indicates the user is looking for a girl
        registration_examples(
          keywords(:girlfriend),
          :expected_looking_for => :female
        )

        # the info indicates the user is looking for a guy
        registration_examples(
          keywords(:boyfriend),
          :expected_looking_for => :male
        )

        # the info indicates the user is looking for a friend
        registration_examples(
          keywords(:friend),
          :expected_looking_for => :either
        )

        # the info indicates a guy is texting looking for a girl
        registration_examples(
          keywords(:guy_looking_for_a_girl),
          :expected_gender => :male,
          :expected_looking_for => :female
        )

        # the info indicates a girl is texting looking for a guy
        registration_examples(
          keywords(:girl_looking_for_a_guy),
          :expected_gender => :female,
          :expected_looking_for => :male
        )

        # the info indicates a guy looking for guy
        registration_examples(
          keywords(:guy_looking_for_a_guy),
          :expected_gender => :male,
          :expected_looking_for => :male
        )

        # the info indicates a girl looking for girl
        registration_examples(
          keywords(:girl_looking_for_a_girl),
          :expected_gender => :female,
          :expected_looking_for => :female
        )

        # the info indicates a guy looking for friend
        registration_examples(
          keywords(:guy_looking_for_a_friend),
          :expected_gender => :male,
          :expected_looking_for => :either
        )

        # the info indicates a girl looking for friend
        registration_examples(
          keywords(:girl_looking_for_a_friend),
          :expected_gender => :female,
          :expected_looking_for => :either
        )

        # guy named frank
        registration_examples(
          keywords(:guy_named_frank),
          :expected_name => "frank",
          :expected_gender => :male
        )

        # girl named mara
        registration_examples(
          keywords(:girl_named_mara),
          :expected_name => "mara",
          :expected_gender => :female
        )

        # 23 year old
        registration_examples(
          keywords(:"23_year_old"),
          :expected_age => 23
        )

        # davo 28 guy wants friend
        registration_examples(
          keywords(:davo_28_guy_wants_bf),
          :expected_age => 28,
          :expected_name => "davo",
          :expected_gender => :male,
          :expected_looking_for => :either
        )

        # put location based examples below here

        # Phnom Penhian
        registration_examples(
          keywords(:phnom_penhian),
          :expected_city => "Phnom Penh",
          :vcr => {:expect_results => true}
        )

        # mara 25 phnom penh wants friend
        registration_examples(
          keywords(:mara_25_pp_wants_friend),
          :expected_age => 25,
          :expected_city => "Phnom Penh",
          :expected_name => "mara",
          :expected_looking_for => :either,
          :vcr => {:expect_results => true}
        )

        # someone from siem reap wants to meet a girl
        registration_examples(
          keywords(:sr_wants_girl),
          :expected_city => "Siem Reap",
          :expected_looking_for => :female,
          :vcr => {:expect_results => true, :cassette => "kh/siem_reab"}
        )

        # kunthia 23 siem reap girl wants boy
        registration_examples(
          keywords(:kunthia_23_sr_girl_wants_boy),
          :expected_age => 23,
          :expected_gender => :female,
          :expected_city => "Siem Reap",
          :expected_name => "kunthia",
          :expected_looking_for => :male,
          :vcr => {:expect_results => true, :cassette => "kh/siem_reab"}
        )
      end
    end
  end

  describe "#matches" do
    it "should return all the matches for a user" do
      subject.class.stub(:matches).with(subject).and_return([new_user])
      subject.class.should_receive(:matches).with(subject)
      subject.matches.should == [new_user]
    end
  end

  describe "#match" do
    it "should return the first match from .matches" do
      subject.class.stub(:matches).with(subject).and_return([new_user])
      subject.class.should_receive(:matches).with(subject)
      subject.match.should == new_user
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

  describe "#available?" do
    it "should only return true if the user is online and not currently chatting" do
      user.should be_available
      offline_user.should_not be_available
      active_chat
      user.should_not be_available
    end
  end

  describe "#first_message?" do
    it "should return true only if the user has one message" do
      user.first_message?.should be_false

      create(:message, :user => user)
      user.first_message?.should be_true

      create(:message, :user => user)
      user.first_message?.should be_false
    end
  end

  describe "#missing_profile_attributes" do
    it "should return the missing attributes of the user" do
      subject.missing_profile_attributes.should == [:name, :date_of_birth, :gender, :city, :looking_for]
      user_with_complete_profile.missing_profile_attributes.should == []

      user_with_complete_profile.date_of_birth = nil
      user_with_complete_profile.missing_profile_attributes.should == [:date_of_birth]
    end
  end

  describe "#locale" do
    it "should return a lowercase symbol of the locale" do
      subject.locale = :EN
      subject.locale.should == :en
    end

    context "if the locale is nil" do
      it "should delegate to #country_code and convert it to a symbol" do
        user.locale = nil
        user.country_code.should be_present
        user.locale.should == user.country_code.to_sym
      end
    end
  end

  describe "#twilio_number" do
    include PhoneCallHelpers::Twilio

    it "should return the correct twilio number for the user" do
      subject.mobile_number = "85512323348"
      subject.twilio_number.should == twilio_number(:default => false)

      subject.mobile_number = "61413455442"
      subject.twilio_number.should == twilio_number

      subject.mobile_number = "12345678906"
      subject.twilio_number.should == twilio_number
    end
  end

  describe "#city" do
    it "should delegate to location" do
      subject.city.should be_nil
      user_with_complete_profile.city.should be_present
    end
  end

  describe "#country_code" do
    it "should delegate to location" do
      subject.country_code.should be_nil
      user.country_code.should be_present
    end
  end

  describe "#address" do
    it "should delegate to location" do
      new_user.location.address = "some address"
      new_user.address.should == "some address"

      new_user.address = "another address"
      new_user.location.address.should == "another address"
    end
  end

  describe "#locate!" do
    it "should delegate to location" do
      new_user.location.stub(:locate!)
      new_user.location.should_receive(:locate!)
      new_user.locate!
    end
  end

  shared_examples_for "setting a gender related attribute" do |attribute_reader|

    attribute_writer = "#{attribute_reader}="

    context "1" do
      it "should be male" do
        subject.send(attribute_writer, "1")
        subject.send(attribute_reader).should == "m"
      end
    end

    context "2" do
      it "should be female" do
        subject.send(attribute_writer, "2")
        subject.send(attribute_reader).should == "f"
      end
    end

    context "any other value" do
      it "should respect the value" do
        subject.send(attribute_writer, "3")
        subject.send(attribute_reader).should == "3"

        subject.send(attribute_writer, :m)
        subject.send(attribute_reader).should == :m
      end
    end
  end

  describe "#gender=" do
    it_should_behave_like "setting a gender related attribute", :gender
  end

  describe "#looking_for=" do
    it_should_behave_like "setting a gender related attribute", :looking_for
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

      it "should set the user's date of birth to nil" do
        subject.date_of_birth.should be_nil
      end
    end
  end

  describe "#currently_chatting?" do
    context "given the user is in an active chat session" do
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

  describe "#short_code" do
    it "should return the correct short code for the given service provider" do
      with_service_providers do |service_provider, prefix, short_code, factory_name|
        new_user = subject.class.new(:mobile_number => build(factory_name).mobile_number)
        new_user.short_code.should == short_code
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

    context "the user has not yet been validated" do
      it "should return a combination of the screen name and 0" do
        subject.screen_id.should be_nil
      end
    end
  end

  describe "#login!" do
    it "should put the user online" do
      offline_user.should_not be_online
      offline_user.login!
      offline_user.should be_online

      # test that we simply return for user's who are already online
      duplicate_user = build(:user, :mobile_number => offline_user.mobile_number)
      duplicate_user.should be_online
      duplicate_user.login!
      duplicate_user.should be_online
    end
  end

  describe "#logout!" do
    let(:reply) { reply_to(user) }
    let(:reply_to_partner) { reply_to(friend, active_chat) }

    it "should put the user offline" do
      user.logout!
      user.should_not be_online
    end

    context "passing no options" do
      before do
        user.logout!
      end

      it "should not create any notifications" do
        reply.should be_nil
        reply_to_partner.should be_nil
      end
    end

    context ":notify => true" do
      it "should notify the user that they are now offline and inform him how to meet someone new" do
        expect_message do
          user.logout!(:notify => true)
        end
        reply.body.should == spec_translate(:anonymous_logged_out, user.locale)
      end
    end

    context "given the user is in an active chat session" do
      before do
        active_chat
      end

      it "should deactivate the chat" do
        user.should be_currently_chatting
        friend.should be_currently_chatting

        user.logout!

        user.reload.should be_currently_chatting
        friend.reload
        friend.should_not be_currently_chatting
        friend.should be_online
      end

      context "passing :notify => true" do
        it "should notify the user that they are now offline and inform them how to chat again" do
          expect_message do
            user.logout!(:notify => true)
          end
          reply.body.should == spec_translate(:logged_out_from_chat, user.locale, friend.screen_id)
        end
      end

      context "passing :notify_chat_partner => true" do
        it "should notify the chat partner that their chat has ended" do
          expect_message do
            user.logout!(:notify_chat_partner => true)
          end
          reply_to_partner.body.should == spec_translate(
            :anonymous_chat_has_ended, friend.locale, user.screen_id
          )
          reply.should be_nil
        end
      end
    end
  end

  describe "#welcome!" do
    it "should welcome the user" do
      expect_message do
        user.welcome!
      end
      reply_to(user).body.should == spec_translate(:welcome, [user.locale, user.country_code])
    end
  end

  describe "#update_locale!" do

    def setup_redelivery_scenario(subject, options = {})
      body = "something"

      # create a delivered reply with an alternate translation
      # to test that this reply is redelivered with the alternative translation
      delivered_reply_with_alternate_translation = create(
        :delivered_reply_with_alternate_translation, :user => subject, :body => body
      )

      # create an undelivered reply with an alternate translation to test
      # that this reply should not be redelivered when updating the locale
      create(:reply_with_alternate_translation, :user => subject, :body => body)

      # create another delivered reply without an alternate translation
      # to test that no resend is performed when updating the locale when the last
      # reply has no alternate translation
      delivered_reply = create(
        :delivered_reply, :user => subject, :body => body
      ) if options[:later_no_alternate_translation_reply]

      delivered_reply || delivered_reply_with_alternate_translation
    end

    def assert_update_locale(with_locale, options = {})
      options[:success] = true unless options[:success] == false
      success = options.delete(:success)
      assert_notify = options.delete(:assert_notify)
      later_no_alternate_translation_reply = options.delete(:later_no_alternate_translation_reply)

      subject = create(:user)

      reply_to_redeliver = setup_redelivery_scenario(
        subject, :later_no_alternate_translation_reply => later_no_alternate_translation_reply
      ) if options[:notify]

      if assert_notify
        expect_message { subject.update_locale!(with_locale, options).should send("be_#{success}") }
        assert_deliver(reply_to_redeliver.alternate_translation)
      else
        # this will raise an error if a reply is delivered
        subject.update_locale!(with_locale, options).should send("be_#{success}")
      end

      subject.reload # ensure changes are saved
      success ? subject.locale.should == with_locale.downcase.to_sym : subject.locale.should == subject.country_code.to_sym
    end

    it "should only update the locale of the user for valid locales" do
      assert_update_locale("en")
      assert_update_locale(new_user.country_code)
      assert_update_locale("us", :success => false)
      assert_update_locale("hi im tom what are you doing", :success => false)
    end

    context "passing :notify" do
      it "should try to resend the last message in the new locale only if :notify => true" do
        assert_update_locale("en", :notify => true, :assert_notify => true)
        assert_update_locale(new_user.country_code, :notify => true, :assert_notify => false)
        assert_update_locale(
          "en", :notify => true, :assert_notify => false, :later_no_alternate_translation_reply => true
        )
      end
    end
  end
end
