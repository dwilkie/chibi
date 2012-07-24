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
  let(:male_user) { create(:male_user) }

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
        it "should build a location from the mobile number and assign it to itself" do
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

  it_should_behave_like "analyzable"

  it_should_behave_like "filtering with communicable resources" do
    let(:resources) { [user, friend] }
  end

  describe ".filter_by" do
    it "should include the user's location to avoid loading it for each user" do
      subject.class.filter_by.includes_values.should == [:location]
    end
  end

  describe ".filter_params" do
    context "passing search params" do
      it "should filter the users by the search params" do
        male_user = create(:male_user)
        female_user = create(:female_user)

        user
        offline_user.save
        active_chat

        subject.class.filter_params(:gender => "m").should == [male_user]
        subject.class.filter_params(:gender => "f").should == [female_user]

        subject.class.filter_params(:available => true).should =~ [male_user, female_user]
      end
    end
  end

  describe ".remind!" do
    let(:user_without_recent_interaction) { create(:user_without_recent_interaction) }
    let(:user_with_recent_interaction) { create(:user_with_recent_interaction) }

    def reminders_to(reference_user)
      replies_to(reference_user).where(:created_at => Time.now)
    end

    before do
      user
      user_without_recent_interaction
      user_with_recent_interaction
      Timecop.freeze(Time.now)
    end

    after do
      Timecop.return
    end

    it "should only remind users without interaction in within the last 5 days" do
      expect_message { subject.class.remind! }
      # run it twice to check that we don't resend reminders
      subject.class.remind!

      [user, user_without_recent_interaction].each do |reference_user|
        reminders_to(reference_user).count.should == 1
        reply_to(reference_user).body.should =~ /#{spec_translate(:anonymous_reminder_approx, user.locale)}/
      end

      reminders_to(user_with_recent_interaction).should be_empty
    end
  end

  describe "#remind!" do
    it "should send a reminder to the user" do
      expect_message { user.remind! }
      reply_to(user).body.should =~ /#{spec_translate(:anonymous_reminder_approx, user.locale)}/
    end
  end

  describe ".matches" do
    # User Descriptions
    # see spec/factories.rb for where users are defined

    # Alex has an empty profile
    # Jamie has an empty profile last seen 15 minutes ago
    # Joy is a straight 27 year old female in Phnom Penh
    # Mara is a bisexual 25 year old female in Phnom Penh
    # Pauline is a female
    # Chamroune is looking for a female
    # Dave is a straight 28 year old male in Phnom Penh
    # Luke is a straight 25 year old male in Phnom Penh with 2 initiated chats
    # Con is a straight 37 year old male in Siem Reap last seen 15 minutes ago
    # Paul is a straight 39 year old male in Phnom Penh last seen 30 minutes ago
    # Harriet is a lesbian from Battambang
    # Eva is a lesbian from Siem Reap
    # Reaksmey is bisexual last seen 15 minutes ago

    # Match Explanations

    # Alex has not specified his/her gender or his/her preferred gender (looking for).
    # This is by far the most common case for new users.
    # Since we don't have any information about the user, assume they're a straight male.
    # This is because a straight male would be more disappointed if he got another guy then
    # if a straight girl got another girl. Joy is a straight female,
    # so she matches first. Mara is a bisexual female so she matches second.
    # Pauline is female so she matches third.
    # Reaksmey is bisexual but his gender is unknown so he/she matches before Jamie whos gender
    # and sexual preference remain unknown. Luke is matched next because he has initiated
    # the most chats and was seen in the last 15 minutes followed by Dave who was also seen in the last
    # 15 minutes, followed by Con who chatted more recently than Paul. It's important to note
    # that we don't want to eliminate the guys from the search because
    # they are potential matches for straight females

    # Jamie gets the similar results as alex

    # Chamroune is looking for a female so all males are eliminated from the match.
    # Also we assume that because Chamroune is looking for a female that he is male. Which
    # is why Joy matches first in this case. Alex was seen more recently than Jamie so he or she is
    # matched before Jamie

    # Pauline is female so users who are looking for males eliminated from the match.
    # Also we assume that because Pauline is a female she is looking for a male.
    # Which is why the boys match before the girls. Similarly, Reaksmey matches before Mara
    # because of we are assuming that Pauline is straight and therefore would not be interested
    # in Mara, so even though Reaksmey's gender is unknown it's still more likely a match.
    # Luke has initiated more chats than the other boys so he matches first.

    # Nok is a straight female. There are other straight males but they are not in Thailand
    # so she can't be matched with them. Hanh and View are both males from Thailand
    # but they are gay so she also can't be matched with either of them. Michael is a guy from Thailand
    # who is bisexual so Michael matches with Nok.

    # Joy is a straight female in Cambodia, so she matches with all the straight males first.
    # Dave and Luke were both seen in the last 15 minutes but Dave matches before Luke
    # because his is older than Joy by 2 years where as Luke is 2 years younger. Con and Paul have
    # initiated the same amount of chats but Con matches first because he is closer in age to Joy.
    # Chamroune is included because he is looking for a female, and we assume he's a male
    # Alex and Jamie are included last

    # Dave is a straight male in Cambodia. Harriet, Eva, Mara and Joy are all females in Cambodia however
    # Harriet and Eva are lesbian, so they are ruled out. Mara is bisexual and Joy is straight so Joy
    # matches before Mara. Similarly, Mara matches before Pauline because Paulines preferred gender
    # unknown. Again alex and Jamie are matched last

    # Con is a straight male from Cambodia, but he has already chatted with Mara, so Con matches
    # with Pauline then Alex and Jamie similar to the previous example

    # Paul and Luke's matches are similar to Dave's match (not sure if it should be for Luke though)

    # Harriet is a lesbian so she can only be matched with females. Straight females are also
    # eliminated from the result. This leaves Eva who is also a lesbian,
    # Mara who is bisexual, Pauline who is a female
    # and Chamroune who is looking for a female and Alex and Jamie
    # Eva is is currently chatting so she is eliminated from the match

    # Eva gets the same results as Harriet

    # Hanh is gay and lives in Thailand. Michael is bisexual and View is gay so View matches first

    # View has previously chatted with Michael and Hanh is offline, so nobody is matched

    # Mara is bisexual, so she doesn't care about the gender she gets. Therefore the only
    # thing that is important is that she is matched with others that are seeking her gender.
    # Also she would be probably be most happy if she was matched with other bisexuals, so Reasmey
    # matches first. Luke, Dave, Chamroune and Paul are all seeking females so they match next.
    # Eva and Harriet are currently chatting and Mara has already chatted with Con so they're
    # all eliminated from the match. Luke, Dave and Paul match before Pauline because it's unknown
    # whether pauline is searching for a guy or a girl.

    # Reaskmey is bisexual but his/her gender is unknown. Mara matches first because she is also
    # bisexual. Then we assume that Reaksmey is a male so people seeking males are matched next.

    # Michael has previously chatted with View which leaves Nok and Hanh. Even though Nok hasn't specified
    # her age yet, we give her the benifit of the doubt and assume she's in the free age zone.
    # Hanh has initiated more chat than Nok so he would have been matched before Nok, but
    # Hanh is offline so he is eliminated from the results anyway.

    # Finally all of these users use mobile numbers which are not from a registered service provider
    # We don't want to match these users with users that have mobile numbers which are from
    # registered service providers. For example, say there are two registered service providers
    # in Cambodia Smart and Mobitel. If a Metfone user contacts the app through the test gateway
    # We don't want to match them with the Smart or Mobitel users,
    # incase the test gateway is down or something.

    USER_MATCHES = {
      :alex => [:joy, :mara, :pauline, :reaksmey, :jamie, :chamroune, :luke, :dave, :con, :paul],
      :jamie => [:joy, :mara, :pauline, :reaksmey, :alex, :chamroune, :luke, :dave, :con, :paul],
      :chamroune => [:joy, :mara, :pauline, :reaksmey, :alex, :jamie],
      :pauline => [:luke, :dave, :con, :paul, :chamroune, :mara, :alex, :jamie],
      :nok => [:michael],
      :joy => [:dave, :luke, :con, :paul, :chamroune, :reaksmey, :alex, :jamie],
      :dave => [:joy, :mara, :pauline, :reaksmey, :alex, :jamie],
      :con => [:joy, :pauline, :reaksmey, :alex, :jamie],
      :paul => [:joy, :mara, :pauline, :reaksmey, :alex, :jamie],
      :luke => [:joy, :mara, :pauline, :reaksmey, :alex, :jamie],
      :harriet => [:mara, :pauline, :chamroune, :reaksmey, :alex, :jamie],
      :eva => [:mara, :pauline, :chamroune, :reaksmey, :alex, :jamie],
      :hanh => [:view, :michael],
      :view => [],
      :mara => [:reaksmey, :luke, :dave, :chamroune, :paul, :pauline, :alex, :jamie],
      :michael => [:nok],
      :reaksmey => [:mara, :joy, :alex, :jamie, :luke, :dave, :chamroune, :con, :paul]
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
      create(:chat,        :user => dave,       :friend => harriet)
      create(:chat,        :user => con,        :friend => mara)
      create(:chat,        :user => mara,       :friend => nok)
      create(:chat,        :user => hanh,       :friend => nok)
      create(:chat,        :user => luke,       :friend => nok)
      create(:chat,        :user => luke,       :friend => hanh)
      create(:chat,        :user => paul,       :friend => nok)
      create(:chat,        :user => pauline,    :friend => reaksmey)

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
    def keywords(*keys)
      options = keys.extract_options!
      options[:user] ||= user
      options[:country_code] ||= options[:user].country_code
      all_keywords = []
      keys.each do |key|
        key = key.to_s
        english_keywords = MessagingHelpers::EXAMPLES["en"].try(:[], key) || []
        localized_keywords = MessagingHelpers::EXAMPLES.try(:[], options[:country_code].to_s.downcase).try(:[], key) || []
        all_keywords |= (english_keywords | localized_keywords)
      end
      raise "No keywords for #{keys} found!" if all_keywords.empty?
      all_keywords
    end

    def registration_examples(examples, options = {})
      examples.each do |info|
        assert_user_attributes(info, options)
      end
    end

    def assert_user_attributes(info, options = {})
      user = options[:user] || build(:user)

      [:name, :age].each do |attribute|
        user.send("#{attribute}=", options.has_key?(attribute) ? options[attribute] : user.send(attribute))
        options["expected_#{attribute}".to_sym] ||= user.send(attribute)
      end

      [:gender, :looking_for].each do |attribute|
        user.send("#{attribute}=", options.has_key?(attribute) ? options[attribute].to_s[0] : user.send(attribute))
        options["expected_#{attribute}".to_sym] ||= user.send(attribute)
      end

      user.location.city = options[:city] || user.city
      options[:expected_city] ||= user.city

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

      [:gender, :looking_for].each do |attribute|
        expected_attribute = options["expected_#{attribute}".to_sym]
        expected_attribute = expected_attribute.to_s[0] if expected_attribute
        user.send(attribute).should eq(expected_attribute)
      end

      [:name, :age, :city].each do |attribute|
        expected_attribute = options["expected_#{attribute}".to_sym]
        user.send(attribute).should eq(expected_attribute)
      end
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

    context "for users with complete profiles" do
      it "should update the profile with the new information" do
        # im a girl
        registration_examples(
          keywords(:im_a_girl),
          :user => user_with_complete_profile,
          :gender => :male,
          :looking_for => :female,
          :expected_gender => :female,
          :expected_looking_for => :female
        )

        # im looking for a guy
        registration_examples(
          keywords(:im_looking_for_a_guy),
          :user => user_with_complete_profile,
          :looking_for => :female,
          :gender => :female,
          :expected_gender => :female,
          :expected_looking_for => :male
        )
      end
    end

    context "for users with a missing looking for preference" do
      it "should determine the looking for preference from the info" do
        registration_examples(
          keywords(:boy),
          :expected_gender => :male,
          :user => male_user,
        )
      end
    end

    context "for users with a missing gender or sexual preference" do
      it "should determine the missing details from the info" do
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

    context "for new users", :focus do
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
          keywords(:davo_28_guy_wants_friend),
          :expected_age => 28,
          :expected_name => "davo",
          :expected_gender => :male,
          :expected_looking_for => :either
        )

        # not an age
        registration_examples(
          keywords(:not_an_age)
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

        # tongleehey 29 phnom penh guy wants girl
        registration_examples(
          keywords(:tongleehey),
          :expected_age => 29,
          :expected_gender => :male,
          :expected_city => "Phnom Penh",
          :expected_name => "tongleehey",
          :expected_looking_for => :female,
          :vcr => {:expect_results => true}
        )

        # find me a girl!
        registration_examples(
          keywords(:find_me_a_girl),
          :expected_looking_for => :female
        )

        # I'm vanna 26 guy from kampong thom Want to find a girl.
        registration_examples(
          keywords(:vanna_kampong_thom),
          :expected_name => "vanna",
          :expected_gender => :male,
          :expected_age => 26,
          :expected_city => "Kampong Thom",
          :expected_looking_for => :female,
          :vcr => {:expect_results => true, :cassette => "kh/kampong_thum"}
        )

        # veasna: 30 years from kandal want a girl
        registration_examples(
          keywords(:veasna),
          :expected_name => "veasna",
          :expected_age => 30,
          :expected_city => "S'ang",
          :expected_looking_for => :female,
          :vcr => {:expect_results => true, :cassette => "kh/kandaal"}
        )

        # sopheak: hello girl607 can u give me ur phone number ?
        registration_examples(
          keywords(:sopheak)
        )

        # i'm ok, i'm fine, i'm 5 etc
        registration_examples(
          keywords(:im_something_other_than_a_name)
        )

        # my name veayo 21 female from pp want to find friend bõy and gril. Can call or sms.
        registration_examples(
          keywords(:veayo),
          :expected_name => "veayo",
          :expected_age => 21,
          :expected_city => "Phnom Penh",
          :expected_looking_for => :either,
          :expected_gender => :female,
          :vcr => {:expect_results => true}
        )

        # 070 83 85 48, 070-83-85-48
        registration_examples(
          keywords(:telephone_number)
        )

        # hi . name me vannak . a yu nhom 19 chnam
        registration_examples(
          keywords(:vannak),
          :expected_name => "vannak",
          :expected_age => 19
        )

        # boy or girl
        registration_examples(
          keywords(:boy_or_girl)
        )

        # hi ! my name vanny.i'm 17 yearold.i'm boy.I live in pailin. thank q... o:)
        registration_examples(
          keywords(:vanny),
          :expected_name => "vanny",
          :expected_age => 17,
          :expected_city => "Pailin",
          :expected_gender => :male,
          :vcr => {:expect_results => true, :cassette => "kh/krong_pailin"}
        )

        # live in siem reap n u . m 093208006
        registration_examples(
          keywords(:not_a_man_from_siem_reap),
          :expected_city => "Siem Reap",
          :vcr => {:expect_results => true, :cassette => "kh/siem_reab"}
        )

        # kimlong
        registration_examples(
          keywords(:kimlong),
          :expected_name => "kimlong",
          :expected_age => 17,
        )

        # phearak
        registration_examples(
          keywords(:phearak),
          :expected_name => "phearak",
          :expected_age => 30,
          :expected_city => "Phnom Penh",
          :expected_gender => :male,
          :expected_looking_for => :female,
          :vcr => {:expect_results => true}
        )

        # name : makara age : 21year live : pp boy : finegirl number : 010524369
        registration_examples(
          keywords(:makara),
          :expected_name => "makara",
          :expected_age => 21,
          :expected_city => "Phnom Penh",
          :expected_gender => :male,
          :expected_looking_for => :female,
          :vcr => {:expect_results => true}
        )

        # "i bat chhmos ( bros hai ) phet bros rous nov kampong cham a yu 20,mit bros"
        registration_examples(
          keywords(:hai),
          :expected_name => "hai",
          :expected_age => 20,
          :expected_city => "Krouch Chhmar",
          :expected_gender => :male,
          :expected_looking_for => :male,
          :vcr => {:expect_results => true, :cassette => "kh/kampong_chaam"}
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

    context "passing a chat" do
      it "should return true if the users is currently chatting in the passed chat" do
        active_chat
        user.available?(friend.active_chat).should be_true
        user.available?(create(:chat)).should be_false
      end
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

  describe "#opposite_gender" do
    context "gender is 'f'" do
      before do
        subject.gender = "f"
      end

      it "should == 'm'" do
        subject.opposite_gender.should == "m"
      end
    end

    context "gender is 'm'" do
      before do
        subject.gender = "m"
      end

      it "should == 'f'" do
        subject.opposite_gender.should == "f"
      end
    end

    context "gender is not set" do
      it "should be nil" do
        subject.opposite_gender.should be_nil
      end
    end
  end

  describe "#opposite_looking_for" do
    context "looking for is 'f'" do
      before do
        subject.looking_for = "f"
      end

      it "should == 'm'" do
        subject.opposite_looking_for.should == "m"
      end
    end

    context "looking for is 'm'" do
      before do
        subject.looking_for = "m"
      end

      it "should == 'f'" do
        subject.opposite_looking_for.should == "f"
      end
    end

    context "looking for is 'e'" do
      before do
        subject.looking_for = "e"
      end

      it "should be nil" do
        subject.opposite_looking_for.should be_nil
      end
    end

    context "looking for is not set" do
      it "should be nil" do
        subject.opposite_looking_for.should be_nil
      end
    end
  end

  describe "#probable_gender" do
    context "gender is unknown" do
      context "and looking for is unknown" do
        it "should == 'm' (assume the user is a straight male)" do
          subject.probable_gender.should == "m"
        end
      end

      context "and looking for is either" do
        before do
          subject.looking_for = "e"
        end

        it "should == 'm' (assume the user is a bi male)" do
          subject.probable_gender.should == "m"
        end
      end

      context "and looking for is male" do
        before do
          subject.looking_for = "m"
        end

        it "should == 'f' (assume the user is straight)" do
          subject.probable_gender.should == "f"
        end
      end

      context "and looking for is female" do
        before do
          subject.looking_for = "f"
        end

        it "should == 'm' (assume the user is straight)" do
          subject.probable_gender.should == "m"
        end
      end
    end

    context "gender is male" do
      before do
        subject.gender = "m"
      end

      it "should == 'm'" do
        subject.probable_gender.should == "m"
      end
    end

    context "gender is female" do
      before do
        subject.gender = "f"
      end

      it "should == 'f'" do
        subject.probable_gender.should == "f"
      end
    end
  end

  describe "#probable_looking_for" do
    context "looking for is unknown" do
      context "and gender is unknown" do
        it "should == 'f' (assume the user is a straight male)" do
          subject.probable_looking_for.should == "f"
        end
      end

      context "and gender is male" do
        before do
          subject.gender = "m"
        end

        it "should == 'f' (assume the user is straight)" do
          subject.probable_looking_for.should == "f"
        end
      end

      context "and gender is female" do
        before do
          subject.gender = "f"
        end

        it "should == 'm' (assume the user is straight)" do
          subject.probable_looking_for.should == "m"
        end
      end
    end

    context "looking for a male" do
      before do
        subject.looking_for = "m"
      end

      it "should == 'm'" do
        subject.probable_looking_for.should == "m"
      end
    end

    context "looking for a female" do
      before do
        subject.looking_for = "f"
      end

      it "should == 'f'" do
        subject.probable_looking_for.should == "f"
      end
    end

    context "looking for either" do
      before do
        subject.looking_for = "e"
      end

      it "should == 'e'" do
        subject.probable_looking_for.should == "e"
      end
    end
  end

  describe "#bisexual?" do
    it "should be true only if the user is explicitly bisexual" do
      subject.should_not be_bisexual

      subject.looking_for = "e"
      subject.should be_bisexual

      subject.gender = "m"
      subject.looking_for = "m"
      subject.should_not be_bisexual
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

  describe "#local_number" do
    it "should return the mobile number of the user without the country code" do
      # Cambodia
      user.mobile_number = "855123456789"
      user.local_number.should == "123456789"

      # Vietnam
      user.mobile_number = "84123456789"
      user.local_number.should == "123456789"

      # US
      user.mobile_number = "1123456789"
      user.local_number.should == "123456789"
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

      it "should return the user's name" do
        user_with_name.screen_id.should == "Sok"
      end
    end

    context "the user has no name" do
      let(:user_without_name) { create(:user, :id => 88) }

      it "should return the user's screen name" do
        user_without_name.screen_id.should == "#{user_without_name.screen_name.capitalize}"
      end
    end

    context "the user has not yet been validated" do
      it "should return nil" do
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
            :anonymous_chat_has_ended, friend.locale
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
