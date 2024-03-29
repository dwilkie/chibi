require 'rails_helper'

describe User do
  include MobilePhoneHelpers
  include PhoneCallHelpers
  include TranslationHelpers
  include MessagingHelpers
  include ActiveJobHelpers
  include AnalyzableExamples

  include_context "replies"

  let(:user) { create(:user, :from_registered_service_provider) }
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
    expect(options[:new_friend]).to be_currently_chatting
    expect(options[:new_friend].active_chat.user).to eq(options[:searcher])
    expect(options[:searcher]).not_to be_currently_chatting
    expect(options[:searcher]).to be_searching_for_friend
  end

  def assert_friend_not_found(options = {})
    options[:searcher] ||= user_searching_for_friend
    options[:new_friend] ||= user
    options[:still_searching] = true unless options[:still_searching] == false

    options[:searcher].reload
    options[:new_friend].reload
    expect(options[:new_friend]).not_to be_currently_chatting
    expect(options[:searcher]).not_to be_currently_chatting
    expect(options[:searcher].searching_for_friend?).to eq(options[:still_searching])
  end

  def create_user(*args)
    options = args.extract_options!
    create(:user, *args, options)
  end

  shared_examples_for "within hours" do |background_job|
    include TimecopHelpers

    context "given the current time is out of user hours" do
      it "should not perform the task" do
        at_time(7, 59) do
          send(task)
          send(negative_assertion)
        end
      end
    end

    context "given the current time is not out of user hours" do
      let(:valid_time) { [User::DEFAULT_USER_HOURS_MIN] }

      def do_task_in_background
        perform_background_job
      end

      def do_task
        send(task, hour_range_options)
      end

      if background_job
        it "should perform the task" do
          at_time(*valid_time) { do_task_in_background }
          send(positive_assertion)
        end
      else
        it "should perform the task" do
          at_time(*valid_time) { do_task }
          send(positive_assertion)
        end
      end
    end
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:mobile_number) }
    it { is_expected.to validate_inclusion_of(:gender).in_array(["m", "f"]) }
    it { is_expected.to validate_inclusion_of(:looking_for).in_array(["m", "f"]) }
    it { is_expected.not_to allow_value(attributes_for(:user, :with_invalid_mobile_number)[:mobile_number]).for(:mobile_number) }
    it { is_expected.not_to allow_value("8559878917").for(:mobile_number) }
    it { is_expected.not_to allow_value("8559620617899").for(:mobile_number) }
    it { is_expected.to validate_uniqueness_of(:mobile_number) }

    context "for persisted users" do
      subject { create(:user) }
      it { is_expected.to validate_presence_of(:screen_name) }
      it { is_expected.to validate_presence_of(:location) }
    end

    context "too old" do
      subject { build(:user, :too_old) }
      it { is_expected.not_to be_valid }
    end

    context "too young" do
      subject { build(:user, :too_young) }
      it { is_expected.not_to be_valid }
    end

    describe "english" do
      subject { build(:user, :english) }
      it { is_expected.to be_valid }
    end

    describe "american" do
      subject { build(:user, :american) }
      it { is_expected.to be_valid }
    end

    describe "thai" do
      subject { build(:user, :thai) }
      it { is_expected.to be_valid }
    end
  end

  it { is_expected.to be_online }

  describe "associations" do
    describe "location" do
      before do
        user
      end

      it "should be autosaved" do
        user.location.city = "Melbourne"
        user.save
        expect(user.location.reload.city).to eq("Melbourne")
      end
    end
  end

  describe "callbacks" do
    context "before_save" do
      context "if the user is currently chatting and also searching" do
        let(:chat_with_user_searching_for_friend) do
          create(:chat, :with_user_searching_for_friend, :user => user_searching_for_friend)
        end

        let(:active_chat_with_user_searching_for_friend) do
          create(:chat, :with_user_searching_for_friend, :initiator_active, :user => user_searching_for_friend)
        end

        it "should no longer be searching for a friend" do
          chat_with_user_searching_for_friend
          expect(user_searching_for_friend.reload).to be_searching_for_friend
          active_chat_with_user_searching_for_friend
          expect(user_searching_for_friend.reload).not_to be_searching_for_friend
        end
      end
    end

    context "before_validation(:on => :create)" do
      it "should generate a screen name" do
        expect(new_user.screen_name).to be_nil
        new_user.valid?
        expect(new_user.screen_name).to be_present
      end

      context "given a mobile number is present" do
        subject { build(:user, :location => nil) }

        it "should assign a location" do
          expect(subject).to receive(:assign_location).with(no_args)
          subject.valid?
        end

        it "should try to assign an operator" do
          subject.valid?
          expect(subject.operator_name).to be_present
        end

        context "setting the receive_sms_ability" do
          subject { build(:user, :mobile_number => mobile_number) }

          before do
            subject.valid?
          end

          context "for known landline numbers" do
            let(:mobile_number) { generate(:landline_number) }
            it { expect(subject).not_to be_can_receive_sms }
          end

          context "for unknown numbers" do
            let(:mobile_number) { generate(:unknown_operator_number) }
            it { expect(subject).to be_can_receive_sms }
          end

          context "for mobile numbers" do
            let(:mobile_number) { generate(:mobile_number) }
            it { expect(subject).to be_can_receive_sms }
          end
        end
      end

      context "given a mobile number is not present" do
        it "should not try to build a location" do
          subject.valid?
          expect(subject.location).to be_nil
        end

        it "should not try to assign an operator" do
          subject.valid?
          expect(subject.operator_name).to be_nil
        end
      end
    end
  end

  it_should_behave_like "analyzable", true do
    let(:group_by_column) { :created_at }

    def operator_name
      resource.operator_name
    end

    def country_code
      resource.country_code
    end

    def create_resource(*args)
      create(:user, *args)
    end
  end

  it_should_behave_like "filtering with communicable resources" do
    let(:resources) { [user, friend] }
  end

  describe ".between_the_ages(ranges)" do
    let(:thirteen_year_old)  { create(:user, :date_of_birth => 13.years.ago) }
    let(:seventeen_year_old) { create(:user, :date_of_birth => 17.years.ago + 1.day) }
    let(:eighteen_year_old)  { create(:user, :date_of_birth => 17.years.ago) }

    let(:users) { [thirteen_year_old, seventeen_year_old, eighteen_year_old] }

    it "should return the users whos age is in the given range" do
      Timecop.freeze(Time.current) do
        expect(User.between_the_ages(13..17)).to match_array([thirteen_year_old, seventeen_year_old])
      end
    end
  end

  describe ".male" do
    before do
      male
      female
    end

    it "should return only the males" do
      expect(User.male).to eq([male])
    end
  end

  describe ".female" do
    before do
      male
      female
    end

    it "should return only the females" do
      expect(User.female).to eq([female])
    end
  end

  describe ".with_date_of_birth" do
    let!(:user_with_date_of_birth) { create(:user, :with_date_of_birth) }

    before do
      user
    end

    it "should only return the users with a date of birth" do
      expect(User.with_date_of_birth).to eq([user_with_date_of_birth])
    end
  end

  describe ".without_gender" do
    before do
      user
      male
    end

    it "should only return the users without a gender" do
      expect(User.without_gender).to eq([user])
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
      expect(User.available).to eq([male])
    end
  end

  describe ".online" do
    before do
      offline_user
      user
    end

    it "should not return users who are offline" do
      expect(described_class.online).to eq([user])
    end
  end

  describe ".find_friends!" do
    def do_find_friends(options = {})
      trigger_job(options) { described_class.find_friends! }
    end

    def perform_background_job
      do_find_friends
    end

    before do
      user_searching_for_friend
      user
    end

    it_should_behave_like "within hours", true do
      let(:positive_assertion) { :assert_friend_found }
      let(:negative_assertion) { :assert_friend_not_found }
      let(:task) { :do_find_friends }
    end
  end

  describe ".filter_by" do
    it "should include the user's location to avoid loading it for each user" do
      expect(described_class.filter_by.includes_values).to include(:location)
    end
  end

  describe ".without_recent_interaction" do
    def create_user(*args)
      options = args.extract_options!
      create(:user, *args, options)
    end

    before do
      user
    end

    context "a user has never had recent interaction" do
      let(:user) { create_user }

      it { expect(described_class.without_recent_interaction).to eq([user]) }
    end

    context "a user has no recent interaction" do
      let(:user) { create_user(:without_recent_interaction) }

      it { expect(described_class.without_recent_interaction).to eq([user]) }
    end

    context "a user has recent interaction" do
      let(:user) { create_user(:with_recent_interaction) }

      it { expect(described_class.without_recent_interaction).to be_empty }
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

        expect(described_class.filter_params(:gender => "m")).to eq([male])
        expect(described_class.filter_params(:gender => "f")).to eq([female])

        expect(described_class.filter_params(:available => true)).to match_array([male, female, thai])
        expect(described_class.filter_params(:country_code => "th")).to eq([thai])
      end
    end
  end

  describe ".remind!" do
    let(:user_not_contacted_recently) { create(:user, :from_unknown_operator, :not_contacted_recently) }

    let(:registered_sp_user_not_contacted_recently) do
      create(:user, :from_registered_service_provider, :not_contacted_recently)
    end

    let(:registered_sp_user_not_contacted_for_a_long_time) do
      create(
        :user, :from_registered_service_provider, :not_contacted_for_a_long_time
      )
    end

    let(:user_without_chibi_smpp_connection) {
      create(
        :user, :not_contacted_for_a_long_time, :from_operator_without_chibi_smpp_connection
      )
    }

    let(:registered_sp_user_not_contacted_for_a_short_time) do
      create(
        :user, :from_registered_service_provider, :not_contacted_for_a_short_time
      )
    end

    let(:registered_sp_user_with_recent_interaction) do
      create(:user, :from_registered_service_provider)
    end

    let(:user_who_cannot_receive_sms) { create(:user, :not_contacted_recently, :cannot_receive_sms) }

    def create_actors
      registered_sp_user_not_contacted_recently
      registered_sp_user_not_contacted_for_a_long_time
      registered_sp_user_not_contacted_for_a_short_time
      registered_sp_user_with_recent_interaction
      user_not_contacted_recently
      user_without_chibi_smpp_connection
      user_who_cannot_receive_sms
    end

    def do_remind(options = {})
      create_actors
      trigger_job(options) { described_class.remind! }
    end

    def perform_background_job(options = {})
      do_remind(options)
    end

    def assert_user_reminded(reference_user)
      expect(replies_to(reference_user).count).to eq(1)
      expect(reply_to(reference_user).body).to be_present
    end

    def assert_reminded
      assert_user_reminded(registered_sp_user_not_contacted_for_a_long_time)
      assert_user_reminded(registered_sp_user_not_contacted_recently)
      expect(reply_to(registered_sp_user_with_recent_interaction)).to be_nil
      expect(reply_to(user_not_contacted_recently)).to be_nil
      expect(reply_to(user_who_cannot_receive_sms)).to be_nil
    end

    def assert_not_reminded
      expect(reply_to(user_without_chibi_smpp_connection)).to be_nil
      expect(reply_to(registered_sp_user_not_contacted_for_a_long_time)).to be_nil
      expect(reply_to(registered_sp_user_not_contacted_recently)).to be_nil
      expect(reply_to(registered_sp_user_with_recent_interaction)).to be_nil
      expect(reply_to(user_not_contacted_recently)).to be_nil
    end

    it_should_behave_like "within hours", true do
      let(:positive_assertion) { :assert_reminded }
      let(:negative_assertion) { :assert_not_reminded }
      let(:task) { :do_remind }
    end
  end

  describe "#operator" do
    it "should return the operator derived from the mobile number" do
      with_operators do |number_parts, assertions|
        number = number_parts.join
        new_user = build(:user, :mobile_number => number)
        expect(new_user.operator.id).to eq(assertions["id"])
      end
    end
  end

  describe "#reply_not_enough_credit!" do
    subject { create(:user) }
    let(:reply) { double(Reply) }

    before do
      allow(reply).to receive(:not_enough_credit!)
      allow(subject).to receive_message_chain(:replies, :build).and_return(reply)
    end

    it "should delegate to a new reply" do
      expect(reply).to receive(:not_enough_credit!)
      subject.reply_not_enough_credit!
    end
  end

  xdescribe "#charge!(requester)" do
    subject { create(:user, :from_chargeable_operator) }
    let(:requester) { Random.new.rand(0..1).zero? ? create(:message, :user => subject) : create(:phone_call, :user => subject) }
    let(:latest_charge_request) { subject.latest_charge_request }
    let(:expired_time_before_new_charge) { 24.hours }

    def create_charge_request(*args)
      options = args.extract_options!
      create(:charge_request, *args, {:user => subject}.merge(options))
    end

    shared_examples_for "charging the user" do |options|
      options ||= {}
      options[:expected_return_value]
      it "should create a charge request with notify_requester => #{options[:notify_requester]} and return #{options[:expected_return_value]}" do
        expect(subject.charge!(requester)).to eq(options[:expected_return_value])
        expect(subject.charge_requests).to include(latest_charge_request)
        expect(latest_charge_request.requester).to eq(requester)
        expect(latest_charge_request.notify_requester).to eq(options[:notify_requester])
        expect(latest_charge_request.operator).to eq(subject.operator.id)
      end
    end

    shared_examples_for "not charging the user" do |options|
      options ||= {}

      before do
        latest_charge_request
      end

      it "should not create a new charge request and it should return #{options[:expected_return_value]}" do
        expect(subject.charge!(requester)).to eq(options[:expected_return_value])
        expect(subject.charge_requests).to eq([latest_charge_request])
        expect(subject.latest_charge_request).to eq(latest_charge_request)
      end
    end

    shared_examples_for "a timed charge request" do
      context "latest charge request is slow" do
        before do
          allow(latest_charge_request).to receive(:slow?).and_return(true)
        end

        it_should_behave_like "not charging the user", :expected_return_value => true
      end

      context "latest charge request is not slow" do
        before do
          allow(latest_charge_request).to receive(:slow?).and_return(false)
        end

        it_should_behave_like "not charging the user", :expected_return_value => false
      end
    end

    context "given the user does not need to be charged" do
      subject { user }

      it "should not charge the user" do
        expect(subject.charge!(requester)).to eq(true)
        expect(subject.charge_requests).to be_empty
        expect(subject.latest_charge_request).to be_nil
      end
    end

    context "given the user has never been charged before" do
      it_should_behave_like "charging the user", :expected_return_value => true, :notify_requester => false
    end

    context "given the user's last charge was just created" do
      it_should_behave_like "a timed charge request" do
        let(:latest_charge_request) { create_charge_request }
      end
    end

    context "given the user's last charge is still awaiting the result" do
      it_should_behave_like "a timed charge request" do
        let(:latest_charge_request) { create_charge_request(:awaiting_result) }
      end
    end

    context "given the user's last charge was errored (our fault)" do
      before do
        create_charge_request(:errored)
      end

      it_should_behave_like "charging the user", :expected_return_value => true, :notify_requester => false
    end

    context "given the user's last charge was successful" do
      context "and it was less than 24 hours ago" do
        it_should_behave_like "not charging the user", :expected_return_value => true do
          let(:latest_charge_request) { create_charge_request(:successful) }
        end
      end

      context "but it was more than 24 hours ago" do
        before do
          create_charge_request(
            :successful,
            :created_at => expired_time_before_new_charge.ago,
            :updated_at => expired_time_before_new_charge.ago
          )
        end

        it_should_behave_like "charging the user", :expected_return_value => true, :notify_requester => false
      end
    end

    context "given the user's last charge was unsuccessful" do
      before do
        create_charge_request(:failed)
      end

      it_should_behave_like "charging the user", :expected_return_value => false, :notify_requester => true
    end
  end

  describe "#remind!" do
    def assert_reminded!
      expect(reply_to(subject).body).to be_present
    end

    def assert_not_reminded!
      expect(reply_to(subject)).to be_nil
    end

    before do
      subject.remind!
    end

    context "given the user needs reminding" do
      subject { create(:user, :not_contacted_recently) }
      it { assert_reminded! }
    end

    context "given the user does not need reminding" do
      subject { create(:user) }
      it { assert_not_reminded! }
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

    # 1. Order by preferred gender
    #    a) he/she is gay
    #       i)  Prefer other gay users of the same gender
    #       ii) Prefer other users of the same sex
    #    b) he/she is not gay
    #       i)  Gender is known - Prefer users of the opposite sex
    #       ii) Gender is unknown - Skip

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
    # Chamroune is has an empty profile last seen just now
    # Jamie has an empty profile last seen 15 minutes ago
    # Joy is a 27 year old female in Phnom Penh last seen 15 minutes ago
    # Mara is a 25 year old female in Phnom Penh last seen 15 minutes ago
    # Pauline is a female last seen just now from a registered service provider
    # Dave is a 28 year old male in Phnom Penh last seen just now
    # Luke is a 25 year old male in Phnom Penh last seen just now
    # Con is a 37 year old male in Siem Reap last seen 15 minutes ago with
    # Paul is a 39 year old male in Phnom Penh last seen 15 minutes ago with
    # Harriet is a lesbian from Battambang last seen 15 minutes ago currently chatting with Eva
    # Eva is a lesbian from Siem Reap last seen 15 minutes ago currently chatting with Harriet
    # Nok is a female from Chiang Mai last seen 15 minutes ago
    # Michael is a 29 year old male from Chiang Mai last seen 15 minutes ago with
    # Hanh is a gay 28 year old male from Chiang Mai last seen 15 minutes ago
    # View is a gay 26 year old male from Chiang Mai last seen 15 minutes ago
    # Reaksmey has never interacted (his last_interacted_at is nil)

    # Individual Match Explanations

    # No profile information is known about Alex,
    # so there is no ordering on gender, age difference nor location.
    # Ordering is based on recent activity only.

    # No Profile information is known about Jamie
    # Similar to Alex, ordering is based on recent activity only

    # No Profile information is known abount Chamroune .
    # Similar to Alex and Jamie, ordering is based on recent activity

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

    # Harriet is a lesbian. Unlike the other girls she matches other lesbians first then the girls, followed by the boys.
    # Dave has already chatted with Harriet so he is eliminated from the results.
    # Eva would have match first (because she is also a lesbian) but she is is eliminated because she is currently chatting with Harriet
    # Pauline is matched first because she is a female with the most recent activity
    # Mara and Joy are matched next because they are female
    # Luke is matched next because of his recent activity and known location
    # Chamroune and Alex are next due to their recent activity
    # Con is matched before Paul because he is closer (in Siem Reap) to Harriet (in Battambang) than
    # Paul (in Phnom Penh).
    # Followed by Jamie (who's location is unknown)
    # Reaksmey matches last because he has *never* interacted

    # Eva is also in Siem Reap and gets a similar result to Harriet (with Dave included)

    # Hanh is a guy living in Thailand. He has already chatted with Nok.
    # View matches first because he is gay
    # Followed by Michael who is male

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
      :harriet => [:pauline, [:mara, :joy], :luke, [:chamroune, :alex], :con, :paul, :jamie, :reaksmey],
      :eva => [:pauline, [:mara, :joy], [:luke, :dave], [:chamroune, :alex], :con, :paul, :jamie, :reaksmey],
      :hanh => [:view, :michael],
      :view => [:nok],
      :mara => [[:dave, :luke], :paul, [:chamroune, :alex, :pauline], [:joy, :jamie], :reaksmey],
      :michael => [:nok],
      :reaksmey => [[:luke, :chamroune, :dave, :alex], [:mara, :joy, :con, :jamie, :paul]],
      :kris => [[:luke, :dave, :pauline, :chamroune, :alex], [:joy, :mara, :jamie], :con, :paul, :reaksmey],
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
          results = described_class.matches(send(user))
          result_names = results.map { |result| result.name.to_sym }
          result_index = 0
          matches.each do |expected_match|
            if expected_match.is_a?(Array)
              expect(result_names[result_index..result_index + expected_match.size - 1]).to match_array(expected_match)
              result_index += expected_match.size
            else
              expect(result_names[result_index]).to eq(expected_match)
              result_index += 1
            end
          end

          results.each do |result|
            expect(result).not_to be_readonly
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

      Timecop.freeze(Time.current) do
        VCR.use_cassette(cassette, match_requests_on.merge(:erb => true)) do
          user.update_profile(info)
        end
      end

      [:gender, :looking_for].each do |attribute|
        expected_attribute = options["expected_#{attribute}".to_sym]
        expected_attribute = expected_attribute.to_s[0] if expected_attribute
        expect(user.send(attribute)).to eq(expected_attribute)
      end

      [:name, :age, :city].each do |attribute|
        expected_attribute = options["expected_#{attribute}".to_sym]
        expect(user.send(attribute)).to eq(expected_attribute)
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
        :expected_city => "Banteay Srei",
        :vcr => {:expect_results => true, :cassette => "kh/siem_reab"}
      )

      # kunthia 23 siem reap girl wants boy
      registration_examples(
        keywords(:kunthia_23_sr_girl_wants_boy),
        :expected_age => 23,
        :expected_gender => :female,
        :expected_city => "Banteay Srei",
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
        :expected_city => "Prasat Sambour",
        :vcr => {:expect_results => true, :cassette => "kh/kampong_thum"}
      )

      # veasna: 30 years from kandal want a girl
      registration_examples(
        keywords(:veasna),
        :expected_name => "veasna",
        :expected_age => 30,
        :expected_city => "Kandal",
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
        :expected_city => "Krong Pailin",
        :expected_gender => :male,
        :vcr => {:expect_results => true, :cassette => "kh/krong_pailin"}
      )

      # live in siem reap n u . m 093208006
      registration_examples(
        keywords(:not_a_man_from_siem_reap),
        :expected_city => "Banteay Srei",
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
        :expected_city => "Tbuong Kmoum",
        :expected_gender => :male,
        :vcr => {:expect_results => true, :cassette => "kh/kampong_chaam"}
      )

      registration_examples(
        keywords(:"23_year_old", :country_code => :ph),
        :expected_age => 23,
        :user => create(:user, :filipino)
      )

      registration_examples(
        keywords(:"24_year_old", :country_code => :ph),
        :expected_age => 24,
        :expected_gender => :female,
        :expected_name => "annette",
        :user => create(:user, :filipino)
      )
    end
  end

  describe "#matches" do
    it "should return all the matches for a user" do
      allow(described_class).to receive(:matches).with(subject).and_return([new_user])
      expect(described_class).to receive(:matches).with(subject)
      expect(subject.matches).to eq([new_user])
    end
  end

  describe "#match" do
    it "should return the first match from .matches" do
      allow(described_class).to receive(:matches).with(subject).and_return([new_user])
      expect(described_class).to receive(:matches).with(subject)
      expect(subject.match).to eq(new_user)
    end
  end

  describe "#assign_location(address = nil)" do
    def assert_location_assigned(user, asserted_country_code, asserted_address)
      expect(user.location.country_code).to eq(asserted_country_code.to_s)
      expect(user.location.address).to eq(asserted_address)
    end

    it "should assign a location derived the mobile number" do
      with_users_from_different_countries do |nationality, country_code, address|
        user = build(:user, nationality, :location => nil)
        user.assign_location
        assert_location_assigned(user, country_code, address)

        # test assigning a location with a blank address
        user.location = nil
        user.assign_location("")
        assert_location_assigned(user, country_code, address)

        # test assigning a location with an address
        user.location = nil
        user.assign_location("Red Esky Town")
        assert_location_assigned(user, country_code, "Red Esky Town")

        # test assigning a location to a user who already has a location
        user.assign_location
        assert_location_assigned(user, country_code, "Red Esky Town")
      end
    end
  end

  describe "#online?" do
    it "should only return false for offline users" do
      expect(offline_user).not_to be_online
      expect(user).to be_online
      expect(user_searching_for_friend).to be_online
    end
  end

  describe "#available?" do
    subject { create(:user) }

    context "he is offline" do
      subject { create(:user, :offline) }

      it { is_expected.not_to be_available }
    end

    context "he is online and not currently chatting" do
      it { is_expected.to be_available }
    end

    context "he is currently chatting" do
      context "and his chat is active" do
        before do
          create(:chat, :active, :user => subject)
        end

        it { is_expected.not_to be_available }
      end

      context "but his chat is not active" do
        before do
          create(:chat, :initiator_active, :user => subject)
        end

        it { is_expected.to be_available }
      end
    end
  end

  describe "#locale" do
    it "should delegate to #country_code and convert it to a symbol" do
      expect(user.country_code).to be_present
      expect(user.locale).to eq(user.country_code.to_sym)
    end
  end

  describe "#city" do
    it "should delegate to location" do
      expect(subject.city).to be_nil
      expect(user_with_complete_profile.city).to be_present
    end
  end

  describe "#country_code" do
    it "should delegate to location" do
      expect(subject.country_code).to be_nil
      expect(user.country_code).to be_present
    end
  end

  describe "#search_for_friend!" do
    context "given he is not currently chatting" do
      it "should mark the user as searching for a friend" do
        new_user.search_for_friend!
        expect(new_user.reload).to be_searching_for_friend
        expect(new_user).to be_persisted
      end
    end

    context "given he is currently chatting" do
      before do
        active_chat
      end

      it "should not mark the user as searching for a friend" do
        user.search_for_friend!
        expect(user.reload).not_to be_searching_for_friend
      end
    end
  end

  describe "#female?" do
    context "gender is 'f'" do
      before do
        subject.gender = "f"
      end

      it "should be true" do
        expect(subject).to be_female
      end
    end

    context "gender is 'm'" do
      before do
        subject.gender = "m"
      end

      it "should be false" do
        expect(subject).not_to be_female
      end
    end

    context "gender is not set" do
      it "should be false" do
        expect(subject).not_to be_female
      end
    end
  end

  describe "#opposite_gender" do
    context "gender is 'f'" do
      before do
        subject.gender = "f"
      end

      it "should == 'm'" do
        expect(subject.opposite_gender).to eq("m")
      end
    end

    context "gender is 'm'" do
      before do
        subject.gender = "m"
      end

      it "should == 'f'" do
        expect(subject.opposite_gender).to eq("f")
      end
    end

    context "gender is not set" do
      it "should be nil" do
        expect(subject.opposite_gender).to be_nil
      end
    end
  end

  describe "#gay?" do
    it "should only return try for gay males and females" do
      expect(subject).not_to be_gay
      subject.gender = "m"
      expect(subject).not_to be_gay
      subject.looking_for = "m"
      expect(subject).to be_gay
      subject.looking_for = "f"
      expect(subject).not_to be_gay
      subject.gender = "f"
      expect(subject).to be_gay
    end
  end

  describe "#male?" do
    context "gender is 'm'" do
      before do
        subject.gender = "m"
      end

      it "should be true" do
        expect(subject).to be_male
      end
    end

    context "gender is 'f'" do
      before do
        subject.gender = "f"
      end

      it "should be false" do
        expect(subject).not_to be_male
      end
    end

    context "gender is not set" do
      it "should be false" do
        expect(subject).not_to be_male
      end
    end
  end

  describe "#age=" do
    context "15" do
      it "should set the user's date of birth to 15 years ago" do
        Timecop.freeze(Time.current) do
          subject.age = 15
          expect(subject.date_of_birth).to eq(15.years.ago.to_date)
        end
      end
    end

    context "nil" do
      before do
        subject.age = nil
      end

      it "should set the user's date of birth to nil" do
        expect(subject.date_of_birth).to be_nil
      end
    end
  end

  describe "#currently_chatting?" do
    context "given the user is in an active chat session" do
      before do
        active_chat
      end

      it "should be true" do
        expect(user).to be_currently_chatting
      end
    end

    context "given the user is not in an active chat session" do
      it "should be false" do
        expect(user).not_to be_currently_chatting
      end
    end
  end

  describe "#caller_id(requesting_api_version)" do
    def assert_caller_id(requesting_api_version, assert_twilio_number)
      # regardless of the requesting api it should always return the twilio number
      # if the operator does not have it's own caller_id
      expect(build(:user).caller_id(requesting_api_version)).to eq(twilio_number)

      with_operators do |number_parts, assertions|
        number = number_parts.join
        new_user = build(:user, :mobile_number => number)
        asserted_caller_id = assert_twilio_number ? twilio_number : (assertions["caller_id"] || twilio_number)
        expect(new_user.caller_id(requesting_api_version)).to eq(asserted_caller_id)
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
      expect(factory_user.dial_string(requesting_api_version)).to eq(factory_asserted_dial_string)

      with_operators do |number_parts, assertions|
        number = number_parts.join
        new_user = build(:user, :mobile_number => number)
        if assert_only_number
          asserted_dial_string = asserted_number_formatted_for_twilio(new_user.mobile_number)
        else
          asserted_dial_string = (
            interpolated_assertion(
              assertions["dial_string"],
              :number_to_dial => number,
              :dial_string_number_prefix => assertions["dial_string_number_prefix"],
              :voip_gateway_host => assertions["voip_gateway_host"]
            ) || asserted_default_pbx_dial_string(:number_to_dial => number)
          )
        end
        expect(new_user.dial_string(requesting_api_version)).to eq(asserted_dial_string)
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
      Timecop.freeze(Time.current)
    end

    after do
      Timecop.return
    end

    context "when user.age = 23" do
      before do
        subject.age = 23
      end

      it "should return 23" do
        expect(subject.age).to eq(23)
      end
    end

    context "when the user's date of birth is 23 years ago" do
      subject { create(:user, :date_of_birth => 23.years.ago) }
      it "should return 23" do
        expect(subject.age).to eq(23)
      end
    end

    context "when the user's date of birth is unknown" do
      it "should return nil" do
        expect(subject.age).to be_nil
      end
    end
  end

  describe "#screen_id" do
    context "the user has a name" do
      let(:user_with_name) { create(:user, :with_name, :name => "sok", :id => 69) }

      it "should return the user's name" do
        expect(user_with_name.screen_id).to eq("Sok")
      end
    end

    context "the user has no name" do
      let(:user_without_name) { create(:user, :id => 88) }

      it "should return the user's screen name" do
        expect(user_without_name.screen_id).to eq("#{user_without_name.screen_name.capitalize}")
      end
    end

    context "the user has not yet been validated" do
      it "should return nil" do
        expect(subject.screen_id).to be_nil
      end
    end
  end

  describe "#blacklisted?" do
    it { expect(create(:user, :blacklisted)).to be_blacklisted }
    it { expect(create(:user)).not_to be_blacklisted }
  end

  describe "#login!" do
    it "should put the user online" do
      expect(offline_user).not_to be_online
      offline_user.login!
      expect(offline_user).to be_online

      # test that we simply return for user's who are already online
      duplicate_user = build(:user, :mobile_number => offline_user.mobile_number)
      expect(duplicate_user).to be_online
      duplicate_user.login!
      expect(duplicate_user).to be_online
    end
  end

  describe "#logout!" do
    subject { create(:user) }

    def setup_scenario
    end

    before do
      setup_scenario
      subject.logout!
    end

    it { is_expected.not_to be_online }
    it { expect(Reply).not_to be_any }

    context "given the user is in an active chat" do
      let(:chat) { create(:chat, :active, :user => subject) }
      let(:partner) { chat.friend }

      def setup_scenario
        chat
      end

      it { expect(chat).not_to be_active }
      it { expect(partner).to be_available }
    end
  end

  describe "#find_friends!" do
    def do_find_friends(options = {})
      reference_user = options.delete(:reference_user) || user_searching_for_friend
      reference_user.find_friends!
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
  end
end
