require 'spec_helper'

describe User do
  include MobilePhoneHelpers
  include TranslationHelpers
  include MessagingHelpers
  include ResqueHelpers

  include_context "replies"

  let(:user) { create(:user) }
  let(:user_searching_for_friend) { create(:user, :searching_for_friend) }
  let(:new_user) { build(:user) }
  let(:cambodian) { build(:user, :cambodian) }
  let(:friend) { create(:user) }
  let(:active_chat) { create(:active_chat, :user => user, :friend => friend) }
  let(:offline_user) { build(:user, :offline) }
  let(:user_with_complete_profile) { build(:user, :with_complete_profile) }
  let(:male_user) { create(:user, :male) }

  def assert_friend_found(options = {})
    options[:searcher] ||= user_searching_for_friend
    options[:new_friend] ||= user

    options[:searcher].reload
    options[:new_friend].reload
    options[:new_friend].should be_currently_chatting
    options[:new_friend].active_chat.user.should == options[:searcher]
    options[:searcher].should_not be_currently_chatting
    options[:searcher].should be_searching_for_friend
  end

  def assert_friend_not_found(options = {})
    options[:searcher] ||= user_searching_for_friend
    options[:new_friend] ||= user
    options[:still_searching] = true unless options[:still_searching] == false

    options[:searcher].reload
    options[:new_friend].reload
    options[:new_friend].should_not be_currently_chatting
    options[:searcher].should_not be_currently_chatting
    options[:searcher].searching_for_friend?.should == options[:still_searching]
  end

  shared_examples_for "within hours" do |background_job|
    context "passing :between => 2..14" do

      context "given the current time is not between 02:00 UTC and 14:00 UTC" do
        it "should not perform the task" do
          Timecop.freeze(Time.new(2012, 1, 7, 1)) do
            send(task, :between => 2..14)
            send(negative_assertion)
          end
        end
      end

      context "given the current time is between 02:00 UTC and 14:00 UTC" do
        before do
          Timecop.freeze(Time.new(2012, 1, 7, 14))
          send(task, :between => 2..14, :queue_only => background_job)
        end

        after do
          Timecop.return
        end

        if background_job
          context "and @ the time the task is run it's still between 02:00 UTC and 14:00 UTC" do
            it "should perform the task" do
              perform_background_job
              send(positive_assertion)
            end
          end

          context "and @ the time the task is run it's no longer between 02:00 UTC and 14:00 UTC" do
            it "should not perform the task" do
              Timecop.freeze(Time.new(2012, 1, 7, 14, 1)) do
                perform_background_job
                send(negative_assertion)
              end
            end
          end
        else
          it "should perform the task" do
            send(positive_assertion)
          end
        end
      end
    end
  end

  it "should not be valid without a mobile number" do
    new_user.mobile_number = nil
    new_user.should_not be_valid
  end

  it "should not be valid with an invalid gender" do
    build(:user, :with_invalid_gender).should_not be_valid
  end

  it "should not be valid with an invalid looking for preference" do
    build(:user, :with_invalid_looking_for_preference).should_not be_valid
  end

  it "should not be valid with an invalid age" do
    build(:user, :too_old).should_not be_valid
    build(:user, :too_young).should_not be_valid
  end

  it "should not be valid with an invalid mobile number e.g. a short code" do
    build(:user, :with_invalid_mobile_number).should_not be_valid
  end

  it "should not be valid without a screen name" do
    user.screen_name = nil
    user.should_not be_valid
  end

  it "should not be valid without a location" do
    user.location = nil
    user.should_not be_valid
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
    context "before save" do
      context "if the user is currently chatting and also searching" do
        let(:chat_with_user_searching_for_friend) do
          create(:chat, :with_user_searching_for_friend, :user => user_searching_for_friend)
        end

        let(:active_chat_with_user_searching_for_friend) do
          create(:chat, :with_user_searching_for_friend, :initiator_active, :user => user_searching_for_friend)
        end

        it "should no longer be searching for a friend" do
          chat_with_user_searching_for_friend
          user_searching_for_friend.reload.should be_searching_for_friend
          active_chat_with_user_searching_for_friend
          user_searching_for_friend.reload.should_not be_searching_for_friend
        end
      end
    end

    context "before validation on create" do
      it "should generate a screen name" do
        new_user.screen_name.should be_nil
        new_user.valid?
        new_user.screen_name.should be_present
      end

      context "given a mobile number is present" do
        it "should build a location from the mobile number and assign it to itself" do
          with_users_from_different_countries do |nationality, country_code, address|
            user = build(:user, nationality, :location => nil)
            user.location.should be_nil
            user.valid?
            user.location.country_code.should == country_code.to_s
            user.location.address.should == address
          end
        end
      end

      context "given a mobile number is not present" do
        it "should not try to build a location" do
          subject.valid?
          subject.location.should be_nil
        end
      end
    end
  end

  it_should_behave_like "analyzable", true

  it_should_behave_like "filtering with communicable resources" do
    let(:resources) { [user, friend] }
  end

  describe ".online" do
    let(:offline_user) { create(:user, :offline) }

    before do
      offline_user
      user
    end

    it "should not return users who are offline" do
      subject.class.online.should == [user]
    end
  end

  describe ".purge_invalid_names!" do
    let(:thai_with_invalid_english_name) { create(:user, :thai, :name => "want") }
    let(:thai_with_invalid_cambodian_name) { create(:user, :thai, :name => "jong") }
    let(:cambodian_with_invalid_cambodian_name) { create(:user, :cambodian, :name => "jong") }
    let(:cambodian_with_valid_cambodian_name) { create(:user, :cambodian, :name => "abajongbab") }

    before do
      thai_with_invalid_english_name
      thai_with_invalid_cambodian_name
      cambodian_with_invalid_cambodian_name
      cambodian_with_valid_cambodian_name
    end

    context "passing no options" do
      it "should purge the all invalid english names and invalid names for the users country" do
        with_resque { subject.class.purge_invalid_names! }
        thai_with_invalid_english_name.reload.name.should be_nil
        thai_with_invalid_cambodian_name.reload.name.should be_present
        cambodian_with_invalid_cambodian_name.reload.name.should be_nil
        cambodian_with_valid_cambodian_name.reload.name.should be_present
      end
    end
  end

  describe ".find_friends" do

    def do_find_friends(options = {})
      do_background_task(options) { subject.class.find_friends(options) }
    end

    def perform_background_job
      expect_message { super(queue_name) }
    end

    before do
      user_searching_for_friend
      user
    end

    it "should only try and find friends for users who are looking for them" do
      do_find_friends
      assert_friend_found
    end

    it_should_behave_like "within hours", true do
      let(:positive_assertion) { :assert_friend_found }
      let(:negative_assertion) { :assert_friend_not_found }
      let(:task) { :do_find_friends }
      let(:queue_name) { :friend_messenger_queue }
    end
  end

  describe ".filter_by" do
    it "should include the user's location to avoid loading it for each user" do
      subject.class.filter_by.includes_values.should include(:location)
    end
  end

  describe ".filter_params" do
    context "passing search params" do
      it "should filter the users by the search params" do
        male_user = create(:user, :male)
        female_user = create(:user, :female)

        user
        offline_user.save
        active_chat

        subject.class.filter_params(:gender => "m").should == [male_user]
        subject.class.filter_params(:gender => "f").should == [female_user]

        subject.class.filter_params(:available => true).should =~ [male_user, female_user]
      end
    end
  end

  describe ".remind!(options = {})" do
    let(:user_without_recent_interaction) { create(:user, :without_recent_interaction) }

    let(:registered_sp_user_without_recent_interaction) do
      create(:user, :from_registered_service_provider, :without_recent_interaction)
    end

    let(:registered_sp_user_without_recent_interaction_for_a_longer_time) do
      create(
        :user, :from_registered_service_provider, :without_recent_interaction_for_a_longer_time
      )
    end

    let(:registered_sp_user_without_recent_interaction_for_a_shorter_time) do
      create(
        :user, :from_registered_service_provider, :without_recent_interaction_for_a_shorter_time
      )
    end

    let(:registered_sp_user_with_recent_interaction) do
      create(:user, :from_registered_service_provider)
    end

    def create_actors
      registered_sp_user_without_recent_interaction
      registered_sp_user_without_recent_interaction_for_a_longer_time
      registered_sp_user_without_recent_interaction_for_a_shorter_time
      registered_sp_user_with_recent_interaction
      user_without_recent_interaction
    end

    def do_remind(options = {})
      create_actors unless options.delete(:skip_create_actors)
      do_background_task(options) { expect_message { subject.class.remind!(options) } }
    end

    def perform_background_job
      expect_message { super(queue_name) }
    end

    def assert_user_reminded(reference_user)
      replies_to(reference_user).count.should == 1
      reply_to(reference_user).body.should be_present
    end

    def assert_reminded
      assert_user_reminded(registered_sp_user_without_recent_interaction_for_a_longer_time)
      assert_user_reminded(registered_sp_user_without_recent_interaction)
      reply_to(registered_sp_user_with_recent_interaction).should be_nil
      reply_to(user_without_recent_interaction).should be_nil
    end

    def assert_not_reminded
      reply_to(registered_sp_user_without_recent_interaction_for_a_longer_time).should be_nil
      reply_to(registered_sp_user_without_recent_interaction).should be_nil
      reply_to(registered_sp_user_with_recent_interaction).should be_nil
      reply_to(user_without_recent_interaction).should be_nil
    end

    it "should only remind users without interaction within the last 5 days" do
      do_remind
      assert_reminded
    end

    context "passing :inactivity_period => 3.days" do
      it "should remind users without recent interaction within the last 3 days" do
        do_remind(:inactivity_period => 3.days)
        assert_reminded
        assert_user_reminded(registered_sp_user_without_recent_interaction_for_a_shorter_time)
      end
    end

    context "passing :limit => 1" do
      it "should only remind the user with the longest inactivity period" do
        do_remind(:limit => 1)
        assert_user_reminded(registered_sp_user_without_recent_interaction_for_a_longer_time)
        reply_to(registered_sp_user_without_recent_interaction.reload).should be_nil
      end
    end

    it_should_behave_like "within hours", true do
      let(:positive_assertion) { :assert_reminded }
      let(:negative_assertion) { :assert_not_reminded }
      let(:task) { :do_remind }
      let(:queue_name) { :user_reminderer_queue }
    end
  end

  describe "#remind!(options = {})" do
    let(:user) { create(:user, :without_recent_interaction) }

    def do_remind(options = {})
      expect_message { user.remind!(options) }
    end

    def assert_reminded
      reply_to(user).body.should be_present
    end

    def assert_not_reminded
      reply_to(user).should be_nil
    end

    context "given the user needs reminding" do
      it "should send a reminder to the user" do
        do_remind
        assert_reminded
      end

      context "passing :inactivity_period => 8.days" do
        it "not send a reminder to the user" do
          do_remind(:inactivity_period => 8.days)
          assert_not_reminded
        end
      end
    end

    context "given the user does not need reminding" do
      let(:user) { create(:user) }

      it "should not send a reminder to the user" do
        do_remind
        assert_not_reminded
      end
    end

    it_should_behave_like "within hours" do
      let(:positive_assertion) { :assert_reminded }
      let(:negative_assertion) { :assert_not_reminded }
      let(:task) { :do_remind }
    end
  end

  describe ".matches" do
    # Matching algorithm explanation
    # For the user (he = he OR she):

    # Exclusions:

    # 1. Don't match him with himself
    # 2. Exclude users who he has already chatted with
    # 3. Exclude users who are offline

    # Ordering

    # 1. If his/her gender is known
    #   a) For males
    #     Prefer females
    #   b) For females
    #     Prefer males

    # 2. Order by recent activity. Note: This should come AFTER ordering by gender
    #    for 2 reasons. Firstly, in the common situation where he is matched
    #    with another user who has not been chatting for a long period of time, given the inactive
    #    user does not reply, he will still be ordered higher than other users because he has
    #    a recent interaction. Secondly, it helps to remind users who are inactive.

    # 3. Order by age difference
    # 4. Order by location

    # User Descriptions
    # see spec/factories.rb for where users are defined

    # Alex has an empty profile last seen just now
    # Jamie has an empty profile last seen 15 minutes ago
    # Joy is a straight 27 year old female in Phnom Penh last seen 15 minutes ago
    # Mara is a bisexual 25 year old female in Phnom Penh last seen 15 minutes ago
    # Pauline is a female last seen just now from a registered service provider
    # Chamroune is looking for a female last seen just now
    # Dave is a straight 28 year old male in Phnom Penh last seen just now
    # Luke is a straight 25 year old male in Phnom Penh last seen just now
    # Con is a straight 37 year old male in Siem Reap last seen 15 minutes ago with
    # Paul is a straight 39 year old male in Phnom Penh last seen 15 minutes ago with
    # Harriet is a lesbian from Battambang last seen 15 minutes ago currently chatting with Eva
    # Eva is a lesbian from Siem Reap last seen 15 minutes ago currently chatting with Harriet
    # Nok is a straight female from Chiang Mai last seen 15 minutes ago
    # Michael is a bisexual 29 year old male from Chiang Mai last seen 15 minutes ago with
    # Hanh is a gay 28 year old male from Chiang Mai last seen 15 minutes ago
    # View is a gay 26 year old male from Chiang Mai last seen 15 minutes ago
    # Reaksmey is bisexual last seen 15 minutes ago

    # Individual Match Explanations

    # No profile information is known about Alex,
    # so there is no ordering on gender, age difference nor location.
    # Ordering is based on recent activity only.

    # No Profile information is known about Jamie
    # Similar to Alex, ordering is based on recent activity only

    # Chamroune is looking for a female but for now we are ignoring this data.
    # Since his/her gender and location is unknown his matches are similar to Alex and Jamie's

    # Pauline is female so male users are matched first.
    # Luke and Dave are equal first because they're guys
    # Con and Paul are equal second because they're also guys but were
    # seen less recently than Dave and Luke.
    # Chamroune and Alex are equal 3rd because they have more recent activity than
    # Mara, Joy and Jamie even though their genders are unknown.
    # Mara, Joy and Jamie are therefore equal 4th
    # Reaksmey is excluded because he has already chatted with Pauline.

    # Nok is female from Thailand. The only other users from Thailand are Michael, Hanh and View
    # who are all males. Nok has already chatted with Hanh (and he's also logged out) so he is eliminated
    # Michael and View were both seen 15 minutes ago so they match equal first.

    # Joy is a female in Cambodia, so she matches with all the males first.
    # Dave and Luke were both seen in the last 15 minutes but Dave matches before Luke
    # because his is older than Joy by 2 years where as Luke is 2 years younger.
    # Con matches because Paul because he is closer in age to Joy.
    # Pauline, Chamroune and Alex are equal fifth because of their more recent interaction
    # Finally Reaskmey, Jamie and Mara match last.

    # Dave is a guy in Cambodia. Harriet, Eva, Mara, Pauline and Joy are all females in Cambodia however
    # Harriet and Eva are currently chatting with each other, so they are excluded
    # (also Harriet has previously chatted with Dave).
    # Pauline is the female seen most recently so she is matched first.
    # Mara and Joy are equal second as they are the two remaining females.
    # Luke, Chamroune and Alex are equal third because of their more recent activity
    # Followed by Con, Jamie and Reaksmey who were all seen more than 15 mins ago
    # Paul is matched last because he is more than 10 years older than Dave

    # Con is also a guy in Cambodia. Con has already chatted with Mara so she is eliminated
    # Pauline and Joy match first and second similar to the previous example.
    # In contrast to the previous example, Con matches with Dave, Chamroune and Alex before Luke
    # because Luke is 12 years younger than Con and the age of Chamroune and Alex is not known
    # Paul, Jamie and Reaksmey are matched last because of their less recent activity

    # Paul is also a guy in Cambodia.
    # Similar to the previous example Pauline matches first.
    # In contrast, Joy matches before Mara because she is closer in age to Paul than Mara.
    # Again, Chamroune and Alex match next because of their recent activity and unknown ages
    # Dave matches before Luke because he is closer in age to Paul
    # Luke is however matched next because he was seen more recently than Con, Reaskmey and Jamie

    # Luke is also a guy in Cambodia, however he is younger or the same age
    # as all of the available girls.
    # Again Pauline matches first.
    # Mara is next because she is closer in age than Joy.
    # Dave, Alex and Chamroune are next because of their recent activity
    # Reaksmey and Jamie matched before Con and Paul because even though their age is unknown,
    # Con and Paul are more than 10 years older than Luke.
    # Con matches before Paul because he is closer in age to Luke than Paul

    # Harriet is a girl. Like the other girls she matches with the boys first.
    # Dave has already chatted with Harriet so he is eliminated from the results.
    # Luke is matched first because of his recent activity
    # Con is matched before Paul because he is closer (in Siem Reap) to Harriet (in Battambang) than
    # Paul (in Phnom Penh).
    # Pauline, Chamroune and Alex are next due to their recent activity
    # Followed by Mara, Joy, Jamie and Reaksmey.
    # Eva is eliminated because she is currently chatting with Harriet

    # Eva is also in Siem Reap and gets a similar result to Harriet (with Dave included)

    # Hanh is a guy living in Thailand. He has already chatted with Nok.
    # Michael and View match equal first

    # View has previously chatted with Michael and Hanh is offline, so Nok is matched

    # Mara is a girl. Her matches are similar to Joy's
    # Con is eliminated because he has already chatted with Mara before.

    # Michael is from Thailand. He has previously chatted with View and Hanh is offline so
    # Nok is matched with him

    # Reaskmey's gender is unknown. His/Her matches are simliar to Alex and Jamie's
    # Pauline is eliminated because he/she has already chatted with Pauline.

    # Kris is offline and his/her gender is unknown however his/her age is known.
    # Luke, Dave, Pauline, Chamroune and Alex match first because of their recent activity
    # Followed by Joy, Mara, Reaksmey and Jamie
    # Con and Paul finish last again because of their age difference with Kris

    USER_MATCHES = {
      :alex => [[:chamroune, :luke, :pauline, :dave], [:mara, :paul, :jamie, :reaksmey, :con, :joy]],
      :jamie => [[:chamroune, :luke, :pauline, :dave, :alex], [:mara, :paul, :reaksmey, :con, :joy]],
      :chamroune => [[:luke, :pauline, :dave, :alex], [:mara, :paul, :reaksmey, :con, :joy, :jamie]],
      :pauline => [[:luke, :dave], [:con, :paul], [:alex, :chamroune], [:joy, :mara, :jamie]],
      :nok => [[:michael, :view]],
      :joy => [:dave, :luke, :con, :paul, [:chamroune, :pauline, :alex], [:mara, :jamie, :reaksmey]],
      :dave => [:pauline, [:mara, :joy], [:luke, :chamroune, :alex], [:con, :jamie, :reaksmey], :paul],
      :con => [:pauline, :joy, [:dave, :chamroune, :alex], :luke, [:paul, :jamie, :reaksmey]],
      :paul => [:pauline, :joy, :mara, [:alex, :chamroune], :dave, :luke, [:con, :reaksmey, :jamie]],
      :luke => [:pauline, :mara, :joy, [:dave, :alex, :chamroune], [:reaksmey, :jamie], :con, :paul],
      :harriet => [:luke, :con, :paul, [:pauline, :chamroune, :alex], [:mara, :joy, :jamie, :reaksmey]],
      :eva => [[:dave, :luke], :con, :paul, [:alex, :chamroune, :pauline], [:joy, :mara, :reaksmey, :jamie]],
      :hanh => [[:michael, :view]],
      :view => [:nok],
      :mara => [[:dave, :luke], :paul, [:chamroune, :alex, :pauline], [:joy, :jamie, :reaksmey]],
      :michael => [:nok],
      :reaksmey => [[:luke, :chamroune, :dave, :alex], [:mara, :joy, :con, :jamie, :paul]],
      :kris => [[:luke, :dave, :pauline, :chamroune, :alex], [:joy, :mara, :reaksmey, :jamie], :con, :paul]
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

      # logout hanh and kris
      hanh.logout!
      kris.logout!
    end

    context "given there are other users" do
      include_context "existing users"

      before do
        load_matches
      end

      it "should match the user with the best compatible match" do
        USER_MATCHES.each do |user, matches|
          results = subject.class.matches(send(user))
          result_names = results.map { |result| result.name.to_sym }

          result_index = 0
          matches.each do |expected_match|
            if expected_match.is_a?(Array)
              result_names[result_index..result_index + expected_match.size - 1].should =~ expected_match
              result_index += expected_match.size
            else
              result_names[result_index].should == expected_match
              result_index += 1
            end
          end

          results.each do |result|
            result.should_not be_readonly
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

    context "for users with a gender and looking for preference" do
      let(:user_with_gender_and_looking_for_preference) do
        create(:user, :with_gender, :with_looking_for_preference)
      end

      it "should update the profile with the new information" do
        # im a girl
        registration_examples(
          keywords(:im_a_girl),
          :user => user_with_gender_and_looking_for_preference,
          :gender => :male,
          :looking_for => :female,
          :expected_gender => :female,
          :expected_looking_for => :female
        )

        # im a boy
        registration_examples(
          keywords(:im_a_boy),
          :user => user_with_gender_and_looking_for_preference,
          :gender => :female,
          :looking_for => :male,
          :expected_gender => :male,
          :expected_looking_for => :male
        )

        # im looking for a guy
        registration_examples(
          keywords(:im_looking_for_a_guy),
          :user => user_with_gender_and_looking_for_preference,
          :looking_for => :female,
          :gender => :female,
          :expected_gender => :female,
          :expected_looking_for => :male
        )

        # im looking for a girl
        registration_examples(
          keywords(:im_looking_for_a_girl),
          :user => user_with_gender_and_looking_for_preference,
          :looking_for => :male,
          :gender => :female,
          :expected_gender => :female,
          :expected_looking_for => :female
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
        reference_user = build(:user, :with_complete_profile)
        reference_user.send("#{attribute}=", nil)
        reference_user.should_not be_profile_complete
      end

      user_with_complete_profile.location.city = nil
      user_with_complete_profile.should_not be_profile_complete
    end
  end

  describe "#online?" do
    it "should only return false for offline users" do
      offline_user.should_not be_online
      user.should be_online
      user_searching_for_friend.should be_online
    end
  end

  describe "#available?" do
    context "he is offline" do
      it "should be false" do
        offline_user.should_not be_available
      end
    end

    context "he is online and not currently chatting" do
      it "should be true" do
        user.should be_available
      end
    end

    context "he is currently chatting" do
      context "and his chat is active" do
        before do
          active_chat
        end

        it "should be false" do
          user.should_not be_available
        end
      end

      context "but his chat is not active" do
        let(:active_chat_with_single_friend) do
          create(:active_chat_with_single_friend, :friend => user)
        end

        before do
          active_chat_with_single_friend
        end

        it "should be true" do
          user.should be_available
        end
      end
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
      subject = build(:user, :mobile_number => "85512323348")
      subject.twilio_number.should == twilio_number(:default => false)

      subject = build(:user, :mobile_number => "61413455442")
      subject.twilio_number.should == twilio_number

      subject = build(:user, :mobile_number => "12345678906")
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

  describe "#search_for_friend!" do
    context "given he is not currently chatting" do
      it "should mark the user as searching for a friend" do
        new_user.search_for_friend!.should be_nil
        new_user.reload.should be_searching_for_friend
        new_user.should be_persisted
      end
    end

    context "given he is currently chatting" do
      before do
        active_chat
      end

      it "should not mark the user as searching for a friend" do
        user.search_for_friend!.should be_nil
        user.reload.should_not be_searching_for_friend
      end
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
    it "should be true all the time (don't handle gays for now)" do
      # unknown sexual preference
      subject.should be_hetrosexual

      # gay guy
      subject.gender = "m"
      subject.looking_for = "m"
      subject.should be_hetrosexual

      # bi guy
      subject.looking_for = "e"
      subject.should be_hetrosexual

      # straight guy
      subject.looking_for = "f"
      subject.should be_hetrosexual

      # gay girl
      subject.gender = "f"
      subject.looking_for = "f"
      subject.should be_hetrosexual

      # bi girl
      subject.looking_for = "e"
      subject.should be_hetrosexual

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
    it "should return the correct short code for each different operator" do
      with_operators do |number_parts, assertions|
        new_user = build(:user, :mobile_number => number_parts.join)
        new_user.short_code.should == assertions["short_code"]
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
      let(:user_with_name) { create(:user, :with_name, :name => "sok", :id => 69) }

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

  describe "#find_friends!" do
    def do_find_friends(options = {})
      reference_user = options.delete(:reference_user) || user_searching_for_friend
      reference_user.find_friends!(options)
    end

    before do
      user_searching_for_friend
      user
    end

    context "given the user is searching for a friend" do
      it "should find friends for the user" do
        do_find_friends
        assert_friend_found
      end
    end

    context "given the user is not searching for a friend" do
      let(:user_not_searching_for_friend) { create(:user) }

      it "should not find friends for the user" do
        do_find_friends(:reference_user => user_not_searching_for_friend)
        assert_friend_not_found(
          :searcher => user_not_searching_for_friend, :still_searching => false
        )
      end
    end

    it_should_behave_like "within hours" do
      let(:positive_assertion) { :assert_friend_found }
      let(:negative_assertion) { :assert_friend_not_found }
      let(:task) { :do_find_friends }
    end
  end

  describe "#update_locale!" do
    def setup_redelivery_scenario(subject, options = {})
      body = "something"

      # create a delivered reply with an alternate translation
      # to test that this reply is redelivered with the alternative translation
      delivered_reply_with_alternate_translation = create(
        :reply, :delivered, :with_alternate_translation, :user => subject, :body => body
      )

      # create an undelivered reply with an alternate translation to test
      # that this reply should not be redelivered when updating the locale
      create(:reply, :with_alternate_translation, :user => subject, :body => body)

      # create another delivered reply without an alternate translation
      # to test that no resend is performed when updating the locale when the last
      # reply has no alternate translation
      delivered_reply = create(
        :reply, :delivered, :user => subject, :body => body
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
        assert_deliver(:body => reply_to_redeliver.alternate_translation)
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
