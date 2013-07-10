require 'spec_helper'

describe User do
  include MobilePhoneHelpers
  include PhoneCallHelpers::TwilioHelpers
  include TranslationHelpers
  include MessagingHelpers
  include ResqueHelpers

  include_context "replies"

  let(:user) { create(:user) }
  let(:user_searching_for_friend) { create(:user, :searching_for_friend) }
  let(:new_user) { build(:user) }
  let(:cambodian) { build(:user, :cambodian) }
  let(:friend) { create(:user) }
  let(:active_chat) { create(:chat, :active, :user => user, :friend => friend) }
  let(:offline_user) { create(:user, :offline) }
  let(:user_with_complete_profile) { build(:user, :with_complete_profile) }
  let(:male) { create(:user, :male) }
  let(:female) { create(:user, :female) }

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

  describe ".between_the_ages(ranges)" do
    let!(:thirteen_year_old)  { create(:user, :date_of_birth => 13.years.ago) }
    let!(:seventeen_year_old) { create(:user, :date_of_birth => 17.years.ago + 1.day) }
    let!(:eighteen_year_old)  { create(:user, :date_of_birth => 17.years.ago) }

    it "should return the users whos age is in the given range" do
      User.between_the_ages(13..17).should =~ [thirteen_year_old, seventeen_year_old]
    end
  end

  describe ".male" do
    before do
      male
      female
    end

    it "should return only the males" do
      User.male.should == [male]
    end
  end

  describe ".female" do
    before do
      male
      female
    end

    it "should return only the females" do
      User.female.should == [female]
    end
  end

  describe ".with_date_of_birth" do
    let!(:user_with_date_of_birth) { create(:user, :with_date_of_birth) }

    before do
      user
    end

    it "should only return the users with a date of birth" do
      User.with_date_of_birth.should == [user_with_date_of_birth]
    end
  end

  describe ".without_gender" do
    before do
      user
      male
    end

    it "should only return the users without a gender" do
      User.without_gender.should == [user]
    end
  end

  describe ".available" do
    before do
      male
      user
      offline_user
      active_chat
    end

    it "should only return users who are online and not currently chatting" do
      User.available.should == [male]
    end
  end

  describe ".online" do
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
        do_background_task { subject.class.purge_invalid_names! }
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
        male
        female
        thai = create(:user, :thai)

        user
        offline_user
        active_chat

        subject.class.filter_params(:gender => "m").should == [male]
        subject.class.filter_params(:gender => "f").should == [female]

        subject.class.filter_params(:available => true).should =~ [male, female, thai]
        subject.class.filter_params(:country_code => "th").should == [thai]
      end
    end
  end

  describe ".remind!(options = {})" do
    let(:user_not_contacted_recently) { create(:user, :not_contacted_recently) }

    let(:registered_sp_user_not_contacted_recently) do
      create(:user, :from_registered_service_provider, :not_contacted_recently)
    end

    let(:registered_sp_user_not_contacted_for_a_long_time) do
      create(
        :user, :from_registered_service_provider, :not_contacted_for_a_long_time
      )
    end

    let(:registered_sp_user_not_contacted_for_a_short_time) do
      create(
        :user, :from_registered_service_provider, :not_contacted_for_a_short_time
      )
    end

    let(:registered_sp_user_with_recent_interaction) do
      create(:user, :from_registered_service_provider)
    end

    def create_actors
      registered_sp_user_not_contacted_recently
      registered_sp_user_not_contacted_for_a_long_time
      registered_sp_user_not_contacted_for_a_short_time
      registered_sp_user_with_recent_interaction
      user_not_contacted_recently
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
      assert_user_reminded(registered_sp_user_not_contacted_for_a_long_time)
      assert_user_reminded(registered_sp_user_not_contacted_recently)
      reply_to(registered_sp_user_with_recent_interaction).should be_nil
      reply_to(user_not_contacted_recently).should be_nil
    end

    def assert_not_reminded
      reply_to(registered_sp_user_not_contacted_for_a_long_time).should be_nil
      reply_to(registered_sp_user_not_contacted_recently).should be_nil
      reply_to(registered_sp_user_with_recent_interaction).should be_nil
      reply_to(user_not_contacted_recently).should be_nil
    end

    it "should only remind users that have not been contacted in the last 5 days" do
      do_remind
      assert_reminded
    end

    context "passing :inactivity_period => 3.days" do
      it "should remind users that have not been contacted in the last 3 days" do
        do_remind(:inactivity_period => 3.days)
        assert_reminded
        assert_user_reminded(registered_sp_user_not_contacted_for_a_short_time)
      end
    end

    context "passing :limit => 1" do
      it "should only remind the user who was contacted least recently" do
        do_remind(:limit => 1)
        assert_user_reminded(registered_sp_user_not_contacted_for_a_long_time)
        reply_to(registered_sp_user_not_contacted_recently.reload).should be_nil
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
    let(:user) { create(:user, :not_contacted_recently) }

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
    # Reaksmey is bisexual who has never interacted (his last_interacted_at is nil)

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
    # Followed by Con and Jamie who were both seen more than 15 mins ago
    # Paul is matched next because he is more than 10 years older than Dave
    # Reaksmey matches last because he has *never* interacted

    # Con is also a guy in Cambodia. Con has already chatted with Mara so she is eliminated
    # Pauline and Joy match first and second similar to the previous example.
    # In contrast to the previous example, Con matches with Dave, Chamroune and Alex before Luke
    # because Luke is 12 years younger than Con and the age of Chamroune and Alex is not known
    # Paul and Jamie are matched next because of their less recent activity
    # Reaksmey matches last because he has *never* interacted

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
    # Jamie is matched before Con and Paul because even though his/her age is unknown,
    # Con and Paul are more than 10 years older than Luke.
    # Con matches before Paul because he is closer in age to Luke than Paul
    # Reaksmey matches last because he has *never* interacted

    # Harriet is a girl. Like the other girls she matches with the boys first.
    # Dave has already chatted with Harriet so he is eliminated from the results.
    # Luke is matched first because of his recent activity
    # Con is matched before Paul because he is closer (in Siem Reap) to Harriet (in Battambang) than
    # Paul (in Phnom Penh).
    # Pauline, Chamroune and Alex are next due to their recent activity
    # Followed by Mara, Joy, Jamie
    # Reaksmey matches last because he has *never* interacted
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
    # Followed by Joy, Mara and Jamie
    # Con and Paul finish next because of their age difference with Kris
    # Reaksmey matches last because he has *never* interacted

    USER_MATCHES = {
      :alex => [[:chamroune, :luke, :pauline, :dave], [:mara, :paul, :jamie, :con, :joy], :reaksmey],
      :jamie => [[:chamroune, :luke, :pauline, :dave, :alex], [:mara, :paul, :con, :joy], :reaksmey],
      :chamroune => [[:luke, :pauline, :dave, :alex], [:mara, :paul, :con, :joy, :jamie], :reaksmey],
      :pauline => [[:luke, :dave], [:con, :paul], [:alex, :chamroune], [:joy, :mara, :jamie]],
      :nok => [[:michael, :view]],
      :joy => [:dave, :luke, :con, :paul, [:chamroune, :pauline, :alex], [:mara, :jamie], :reaksmey],
      :dave => [:pauline, [:mara, :joy], [:luke, :chamroune, :alex], [:con, :jamie], :paul, :reaksmey],
      :con => [:pauline, :joy, [:dave, :chamroune, :alex], :luke, [:paul, :jamie], :reaksmey],
      :paul => [:pauline, :joy, :mara, [:alex, :chamroune], :dave, :luke, [:con, :jamie], :reaksmey],
      :luke => [:pauline, :mara, :joy, [:dave, :alex, :chamroune], :jamie, :con, :paul, :reaksmey],
      :harriet => [:luke, :con, :paul, [:pauline, :chamroune, :alex], [:mara, :joy, :jamie], :reaksmey],
      :eva => [[:dave, :luke], :con, :paul, [:alex, :chamroune, :pauline], [:joy, :mara, :jamie], :reaksmey],
      :hanh => [[:michael, :view]],
      :view => [:nok],
      :mara => [[:dave, :luke], :paul, [:chamroune, :alex, :pauline], [:joy, :jamie], :reaksmey],
      :michael => [:nok],
      :reaksmey => [[:luke, :chamroune, :dave, :alex], [:mara, :joy, :con, :jamie, :paul]],
      :kris => [[:luke, :dave, :pauline, :chamroune, :alex], [:joy, :mara, :jamie], :con, :paul, :reaksmey]
    }

    USER_MATCHES.each do |user, matches|
      let(user) { create(user) }
    end

    def load_matches
      USER_MATCHES.each do |user, matches|
        send(user)
      end

      # create some chats
      create(:chat, :active,  :user => eva,     :friend => harriet)
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

  describe "#update_profile(info)" do
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
      user = options[:user] || create(:user)

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

    it "should try to determine the profile from the info provided" do
      # the info indicates a guy is texting
      registration_examples(
        keywords(:boy),
        :expected_gender => :male
      )

      # the info indicates a girl is texting
      registration_examples(
        keywords(:girl),
        :expected_gender => :female
      )

      # the info indicates a guy is gay
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
        :expected_gender => :male
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
        :vcr => {:expect_results => true}
      )

      # someone from siem reap wants to meet a girl
      registration_examples(
        keywords(:sr_wants_girl),
        :expected_city => "Siem Reap",
        :vcr => {:expect_results => true, :cassette => "kh/siem_reab"}
      )

      # kunthia 23 siem reap girl wants boy
      registration_examples(
        keywords(:kunthia_23_sr_girl_wants_boy),
        :expected_age => 23,
        :expected_gender => :female,
        :expected_city => "Siem Reap",
        :expected_name => "kunthia",
        :vcr => {:expect_results => true, :cassette => "kh/siem_reab"}
      )

      # tongleehey 29 phnom penh guy wants girl
      registration_examples(
        keywords(:tongleehey),
        :expected_age => 29,
        :expected_gender => :male,
        :expected_city => "Phnom Penh",
        :expected_name => "tongleehey",
        :vcr => {:expect_results => true}
      )

      # find me a girl!
      registration_examples(
        keywords(:find_me_a_girl)
      )

      # I'm vanna 26 guy from kampong thom Want to find a girl.
      registration_examples(
        keywords(:vanna_kampong_thom),
        :expected_name => "vanna",
        :expected_gender => :male,
        :expected_age => 26,
        :expected_city => "Kampong Thom",
        :vcr => {:expect_results => true, :cassette => "kh/kampong_thum"}
      )

      # veasna: 30 years from kandal want a girl
      registration_examples(
        keywords(:veasna),
        :expected_name => "veasna",
        :expected_age => 30,
        :expected_city => "S'ang",
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
        :vcr => {:expect_results => true}
      )

      # name : makara age : 21year live : pp boy : finegirl number : 010524369
      registration_examples(
        keywords(:makara),
        :expected_name => "makara",
        :expected_age => 21,
        :expected_city => "Phnom Penh",
        :expected_gender => :male,
        :vcr => {:expect_results => true}
      )

      # "i bat chhmos ( bros hai ) phet bros rous nov kampong cham a yu 20,mit bros"
      registration_examples(
        keywords(:hai),
        :expected_name => "hai",
        :expected_age => 20,
        :expected_city => "Krouch Chhmar",
        :expected_gender => :male,
        :vcr => {:expect_results => true, :cassette => "kh/kampong_chaam"}
      )
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
          create(:chat, :friend_active, :friend => user)
        end

        before do
          active_chat_with_single_friend
        end

        it "should be true" do
          user.should be_available
        end
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
    it "should delegate to #country_code and convert it to a symbol" do
      user.country_code.should be_present
      user.locale.should == user.country_code.to_sym
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

  describe "#gay?" do
    it "should only return try for gay males and females" do
      subject.should_not be_gay
      subject.gender = "m"
      subject.should_not be_gay
      subject.looking_for = "m"
      subject.should be_gay
      subject.looking_for = "f"
      subject.should_not be_gay
      subject.gender = "f"
      subject.should be_gay
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
        subject.date_of_birth.should == 15.years.ago.to_date
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

  describe "#can_call_short_code?" do
    it "should return true only if the user belongs to a operator supporting voice" do
      user.should_not be_can_call_short_code

      with_operators do |number_parts, assertions|
        number = number_parts.join
        new_user = build(:user, :mobile_number => number)
        if assertions["caller_id"]
          new_user.should be_can_call_short_code
        else
          new_user.should_not be_can_call_short_code
        end
      end
    end
  end

  describe "#contact_me_number" do
    it "should retun the user's operator's SMS short code or the twilio number" do
      user.contact_me_number.should == twilio_number
      with_operators do |number_parts, assertions|
        build(:user, :mobile_number => number_parts.join).contact_me_number.should == assertions["short_code"]
      end
    end
  end

  describe "#caller_id(requesting_api_version)" do
    def assert_caller_id(requesting_api_version, assert_twilio_number)
      # regardless of the requesting api it should always return the twilio number
      # if the operator does not have it's own caller_id
      build(:user).caller_id(requesting_api_version).should == twilio_number

      with_operators do |number_parts, assertions|
        number = number_parts.join
        new_user = build(:user, :mobile_number => number)
        asserted_caller_id = assert_twilio_number ? twilio_number : (assertions["caller_id"] || twilio_number)
        new_user.caller_id(requesting_api_version).should == asserted_caller_id
      end
    end

    context "requesting_api_version = '2010-04-01'" do
      it "should return the twilio number as the caller id" do
        assert_caller_id("2010-04-01", true)
      end
    end

    context "requesting_api_version = 'adhearsion-twilio-0.0.1'" do
      it "should return a caller id appropriate for the operator" do
        assert_caller_id(sample_adhearsion_twilio_api_version, false)
      end
    end
  end

  describe "#dial_string(requesting_api_version)" do
    def assert_dial_string(requesting_api_version, assert_only_number)
      factory_user = build(:user)
      factory_asserted_dial_string = assert_only_number ? asserted_number_formatted_for_twilio(factory_user.mobile_number) : asserted_default_pbx_dial_string(:number_to_dial => factory_user.mobile_number)
      factory_user.dial_string(requesting_api_version).should == factory_asserted_dial_string

      with_operators do |number_parts, assertions|
        number = number_parts.join
        new_user = build(:user, :mobile_number => number)
        asserted_dial_string = assert_only_number ? asserted_number_formatted_for_twilio(new_user.mobile_number) : (interpolated_assertion(assertions["dial_string"], :number_to_dial => number) || asserted_default_pbx_dial_string(:number_to_dial => number))
        new_user.dial_string(requesting_api_version).should == asserted_dial_string
      end
    end

    context "requesting_api_version = '2010-04-01'" do
      it "should return the mobile number as the dial string" do
        assert_dial_string("2010-04-01", true)
      end
    end

    context "requesting_api_version = 'adhearsion-twilio-0.0.1'" do
      it "should return a dial string appropriate for the operator" do
        assert_dial_string(sample_adhearsion_twilio_api_version, false)
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

    context "given the user is not currently chatting" do
      before do
        user.logout!
      end

      it "should not create any notifications" do
        reply.should be_nil
        reply_to_partner.should be_nil
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
end
