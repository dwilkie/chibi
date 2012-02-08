require 'spec_helper'

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
    :guy_named_frank => ["im frank man", "i'm frank male", "i am frank guy"],
    :girl_named_mara => ["im mara f", "i'm mara girl", "i am mara woman"],
    :"23_year_old" => ["im 23 years old", "23yo", "23 yo", "blah 23 badfa"],
    :phnom_penhian => ["from phnom penh"],
    :mara_25_pp_wants_friend => ["hi im mara 25 pp looking for friends"],
    :davo_28_guy_wants_bf => ["hi my name is davo male 28 looking for friends"]
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
    :guy_named_frank => ["kjom frank pros", "nhom frank bros", "nyom frank pros", "knhom frank pros", "knyom frank bros"],
    :girl_named_mara => ["kjom mara srey", "nhom mara srey", "nyom mara srey", "knhom mara srey", "knyom mara srey"],
    :"23_year_old" => ["kjom 23chnam", "23 chnam", "23", "dsakle 23dadsa"],
    :phnom_penhian => ["mok pi phnum penh" ,"mok pi pp"],
    :mara_25_pp_wants_friend => ["kjom mara 25 pp jong ban met"],
    :davo_28_guy_wants_friend => ["kjom chhmous davo bros 28 rok met srolanh ped doch knea"]
  }
}

describe SearchHandler do
  include TranslationHelpers
  include HandlerHelpers

  include_context "replies"

  let(:user) do
    build(:user)
  end

  let(:offline_user) do
    build(:offline_user)
  end

  let(:cambodian) do
    create(:cambodian)
  end

  describe "#process!" do
    def keywords(*keys)
      options = keys.extract_options!
      options[:user] ||= user
      options[:country_code] ||= options[:user].location.country_code
      all_keywords = []
      keys.each do |key|
        english_keywords = KEYWORDS[:en][key]
        localized_keywords = KEYWORDS.try(:[], options[:country_code].to_s.downcase.to_sym).try(:[], key)
        all_keywords |= localized_keywords.present? ? (english_keywords | localized_keywords) : english_keywords
      end
      all_keywords
    end

    def registration_examples(examples, options)
      examples.each do |message|
        assert_user_attributes(message, options)
        assert_user_attributes(message.upcase, options) if message.present?
      end
    end

    def assert_user_attributes(message, options)
      user_attributes = [:gender, :looking_for, :name, :age]

      options[:user] ||= user

      options[:user].gender = options[:gender] ? options[:gender].to_s[0] : nil
      options[:user].looking_for = options[:looking_for] ? options[:looking_for].to_s[0] : nil
      options[:user].name = options[:name]
      options[:user].age = options[:age]
      options[:user].location.city = options[:city]

      options[:user].stub(:save)
      setup_handler(options[:user], :body => message)

      vcr_options = options[:vcr] || {}

      if vcr_options[:expect_results]
        match_requests_on = {}
        cassette = vcr_options[:cassette] ||= "results"
      else
        match_requests_on = {:match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]}
        cassette = vcr_options[:cassette] ||= "no_results"
      end

      cassette = message if cassette == :message

      Timecop.freeze(Time.now) do
        VCR.use_cassette(cassette, match_requests_on.merge(:erb => true)) do
          process_message
        end
      end

      options[:expected_gender] ? options[:user].should(send("be_#{options[:expected_gender]}")) : options[:user].gender.should(be_nil)
      options[:expected_looking_for] ? options[:user].looking_for.should(eq(options[:expected_looking_for].to_s[0])) : options[:user].looking_for.should(be_nil)
      options[:expected_city] ? options[:user].location.city.should(eq(options[:expected_city])) : options[:user].location.city.should(be_nil)
      options[:expected_name] ? options[:user].name.should(eq(options[:expected_name])) : options[:user].name.should(be_nil)
      options[:expected_age] ? options[:user].age.should(eq(options[:expected_age])) : options[:user].age.should(be_nil)
    end

    def process_message
      subject.process!
    end

    def assert_looking_for(options = {})
      # the message indicates the user is looking for a guy
      registration_examples(
        keywords(:could_mean_boy_or_boyfriend),
        { :expected_looking_for => :male }.merge(options)
      )

      # the message indicates the user is looking for a girl
      registration_examples(
        keywords(:could_mean_girl_or_girlfriend),
        { :expected_looking_for => :female }.merge(options)
      )

      # the message indicates the user is looking for a friend
      registration_examples(
        keywords(:friend),
        { :expected_looking_for => :either}.merge(options)
      )

      # can't determine what he/she is looking for from the message
      registration_examples(
        ["hello", "", "laskhdg"],
        { :expected_looking_for => options[:expected_looking_for_when_undetermined] }.merge(options)
      )
    end

    def assert_gender(options = {})
      # the message indicates a guy is texting
      registration_examples(
        keywords(:boy, :could_mean_boy_or_boyfriend),
        { :expected_gender => :male }.merge(options)
      )

      # the message indicates a girl is texting
      registration_examples(
        keywords(:girl, :could_mean_girl_or_girlfriend),
        { :expected_gender => :female }.merge(options)
      )
    end

    context "for users with a missing gender or looking for preference" do
      it "should determine the missing information based off the message and what the user has already provided" do
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
      it "should try to determine as much info about the user as possible from the message" do
        # the message indicates a guy is texting
        registration_examples(
          keywords(:boy, :could_mean_boy_or_boyfriend),
          :expected_gender => :male
        )

        # the message indicates a girl is texting
        registration_examples(
          keywords(:girl, :could_mean_girl_or_girlfriend),
          :expected_gender => :female
        )

        # the message indicates the user is looking for a girl
        registration_examples(
          keywords(:girlfriend),
          :expected_looking_for => :female
        )

        # the message indicates the user is looking for a guy
        registration_examples(
          keywords(:boyfriend),
          :expected_looking_for => :male
        )

        # the message indicates the user is looking for a friend
        registration_examples(
          keywords(:friend),
          :expected_looking_for => :either
        )

        # the message indicates a guy is texting looking for a girl
        registration_examples(
          keywords(:guy_looking_for_a_girl),
          :expected_gender => :male,
          :expected_looking_for => :female
        )

        # the message indicates a girl is texting looking for a guy
        registration_examples(
          keywords(:girl_looking_for_a_guy),
          :expected_gender => :female,
          :expected_looking_for => :male
        )

        # the message indicates a guy looking for guy
        registration_examples(
          keywords(:guy_looking_for_a_guy),
          :expected_gender => :male,
          :expected_looking_for => :male
        )

        # the message indicates a girl looking for girl
        registration_examples(
          keywords(:girl_looking_for_a_girl),
          :expected_gender => :female,
          :expected_looking_for => :female
        )

        # the message indicates a guy looking for friend
        registration_examples(
          keywords(:guy_looking_for_a_friend),
          :expected_gender => :male,
          :expected_looking_for => :either
        )

        # the message indicates a girl looking for friend
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
          keywords(:phnom_penhian, :country_code => :kh),
          :user => cambodian,
          :expected_city => "Phnom Penh",
          :vcr => {:expect_results => true}
        )

        # mara 25 phnom penh wants friend
        registration_examples(
          keywords(:mara_25_pp_wants_friend, :country_code => :kh),
          :expected_age => 25,
          :expected_city => "Phnom Penh",
          :expected_name => "mara",
          :expected_looking_for => :either,
          :vcr => {:expect_results => true}
        )
      end
    end

    context "given the message text is" do
      context "'stop'" do
        before do
          setup_handler(user, :body => "stop")
          process_message
        end

        it "should logout the user and notify him that he is now offline" do
          replies[0].body.should == spec_translate(
            :chat_has_ended,
            :missing_profile_attributes => user.missing_profile_attributes,
            :offline => true,
            :locale => user.locale
          )

          user.reload.should_not be_online
        end
      end

      context "anything else but 'stop'" do
        context "and the user is offline" do
          before do
            setup_handler(offline_user)
            process_message
          end

          it "should login the user" do
            offline_user.reload.should be_online
          end
        end
      end
    end

    context "given there is no match for this user" do
      before do
        setup_handler(user)
        process_message
      end

      it "should reply saying there are no matches at this time" do
        replies.count.should == 1

        last_reply.body.should == spec_translate(
          :could_not_start_new_chat,
          :users_name => nil,
          :locale => user.locale
        )

        last_reply.to.should == user.mobile_number
      end
    end

    context "given there is a match for this user" do
      def stub_match(options = {})
        unless options[:match] == false
          options[:match] ||= create(:user)
          User.stub(:matches).and_return([options[:match]])
        end
      end

      let(:friend) { create(:english, :id => 888) }
      let(:new_chat) { Chat.last }

      before do
        setup_handler(user)
        Faker::Name.stub(:first_name).and_return("Wilfred")
        stub_match(:match => friend)
      end

      it "should start a new chat session" do
        Chat.count.should == 0
        process_message
        Chat.count.should == 1
        new_chat.active_users.count.should == 2
        new_chat.user.active_chat.should == new_chat
        new_chat.friend.active_chat.should == new_chat
        new_chat.user.should == user
        user.active_chat.should == new_chat
        subject.message.chat.should == new_chat
      end

      it "should create replies for the participants of the chat" do
        process_message
        replies.count.should == 2

        reply_to_user.body.should == spec_translate(
          :new_chat_started,
          :users_name => nil,
          :friends_screen_name => "wilfred888",
          :to_user => true,
          :locale => user.locale
        )

        reply_to_user.to.should == user.mobile_number
        reply_to_user.chat.should == new_chat

        reply_to_friend.body.should == spec_translate(
          :new_chat_started,
          :users_name => nil,
          :friends_screen_name => "wilfred" + user.id.to_s,
          :to_user => false,
          :locale => friend.locale
        )

        reply_to_friend.to.should == friend.mobile_number
        reply_to_friend.chat.should == new_chat
      end
    end
  end
end
