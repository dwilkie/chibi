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
    :"23_year_old" => ["im 23 years old", "23yo", "23 yo"]
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
    :"23_year_old" => ["kjom 23chnam", "23 chnam", "23"]
  }
}

def keywords(country_code, *keys)
  all_keywords = []
  keys.each do |key|
    english_keywords = KEYWORDS[:en][key]
    localized_keywords = KEYWORDS.try(:[], country_code.downcase.to_sym).try(:[], key)
    all_keywords |= localized_keywords.present? ? (english_keywords | localized_keywords) : english_keywords
  end
  all_keywords
end

def user_examples(country_code)

end

def registration_examples(examples, options)
  examples.each do |message|
    assert_user_attributes(message, options)
    assert_user_attributes(message.upcase, options) if message.present?
  end
end

def assert_user_attributes(message, options)
  user_attributes = [:gender, :looking_for, :location, :name, :age]

  gender = options[:gender]
  looking_for = options[:looking_for]
  location = options[:location]
  name = options[:name]
  age = options[:age]

  vcr_options = options[:vcr] || {}
  vcr_options[:cassette] ||= "no_results"

  context "'#{message}'" do
    before do
      subject.user = user
      subject.body = message
      subject.location = user.location
      Timecop.freeze(Time.now) do
        VCR.use_cassette(vcr_options[:cassette], :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]) do
          process_message
        end
      end
    end

    example_name = []

    gender ? example_name << "the user should be #{gender}" : example_name << "the user's gender should be unknown"
    location ? example_name <<  "in #{location}" : example_name << "location unknown"
    looking_for ? example_name <<  "looking for a #{looking_for == :either ? 'friend' : looking_for}" : example_name << "looking for unknown"
    name ? example_name <<  "name is #{name}" : example_name << "name unknown"
    age ? example_name <<  "#{age} years old" : example_name << "age unknown"

    it example_name.join(", ") do
      gender ? user.should(send("be_#{gender}")) : user.gender.should(be_nil)
      looking_for ? user.looking_for.should(eq(looking_for.to_s[0])) : user.looking_for.should(be_nil)
      location ? user.location.city.should(eq(location)) : user.location.city.should(be_nil)
      name ? user.name.should(eq(name)) : user.name.should(be_nil)
      age ? user.age.should(eq(age)) : user.age.should(be_nil)
    end
  end
end

describe SearchHandler do
  let(:user) do
    build(:user_with_location)
  end

  describe "#process!" do

    def process_message
      subject.process!
    end

    context "where the user is" do

      # from 'US'

      # a guy texting
      context "a guy" do
        before do
          user.gender = "m"
        end

        shared_examples_for "a guy texting" do |looking_for|
          context "and the message is" do
            # a guy looking for a guy
            registration_examples(
              keywords("KH", :could_mean_boy_or_boyfriend),
              :gender => :male,
              :looking_for => :male
            )

            # a guy looking for a girl
            registration_examples(
              keywords("KH", :could_mean_girl_or_girlfriend),
              :gender => :male,
              :looking_for => :female
            )

            # a guy looking for a friend
            registration_examples(
              keywords("KH", :friend),
              :gender => :male,
              :looking_for => :either
            )

            # can't determine who they're looking for
            registration_examples(
              ["hello", "", "laskhdg"],
              :gender => :male,
              :looking_for => looking_for
            )
          end
        end

        # not yet known what he's looking for
        it_should_behave_like "a guy texting", nil

        context "and is looking for a" do
          # a guy is already looking for a guy
          context "guy" do
            before do
              user.looking_for = "m"
            end

            it_should_behave_like "a guy texting", :male
          end

          context "girl" do
            # a guy is already looking for a girl
            before do
              user.looking_for = "f"
            end

            it_should_behave_like "a guy texting", :female
          end

          context "friend" do
            # a guy is already looking for a friend
            before do
              user.looking_for = "e"
            end

            it_should_behave_like "a guy texting", :either
          end
        end
      end

      context "a girl" do
        # a girl texting
        before do
          user.gender = "f"
        end

        shared_examples_for "a girl texting" do |looking_for|
          context "and the message is" do
            # a girl looking for a girl
            registration_examples(
              keywords("KH", :could_mean_girl_or_girlfriend),
              :gender => :female,
              :looking_for => :female
            )

            # a girl looking for a guy
            registration_examples(
              keywords("KH", :could_mean_boy_or_boyfriend),
              :gender => :female,
              :looking_for => :male
            )

            # a girl looking for a friend
            registration_examples(
              keywords("KH", :friend),
              :gender => :female,
              :looking_for => :either
            )

            # can't determine they're looking for
            registration_examples(
              ["hello", "", "laskhdg"],
              :gender => :female,
              :looking_for => looking_for
            )
          end
        end

        # not yet known what she's looking for
        it_should_behave_like "a girl texting", nil

        context "and is looking for a" do
          # a girl is already looking for a guy
          context "guy" do
            before do
              user.looking_for = "m"
            end

            it_should_behave_like "a girl texting", :male
          end

          context "girl" do
            # a girl is already looking for a girl
            before do
              user.looking_for = "f"
            end

            it_should_behave_like "a girl texting", :female
          end

          context "friend" do
            # a girl is already looking for a friend
            before do
              user.looking_for = "e"
            end

            it_should_behave_like "a girl texting", :either
          end
        end
      end

      context "looking for a" do
        context "guy" do
          # is already looking for a guy (gender unknown)
          before do
            user.looking_for = "m"
          end

          context "and the message is" do
            # guy texting
            registration_examples(
              keywords("KH", :boy, :could_mean_boy_or_boyfriend),
              :gender => :male,
              :looking_for => :male
            )

            # girl texting
            registration_examples(
              keywords("KH", :girl, :could_mean_girl_or_girlfriend),
              :gender => :female,
              :looking_for => :male
            )
          end
        end

        context "girl" do
          # is already looking for a girl (gender unknown)
          before do
            user.looking_for = "f"
          end

          context "and the message is" do
            # guy texting
            registration_examples(
              keywords("KH", :boy, :could_mean_boy_or_boyfriend),
              :gender => :male,
              :looking_for => :female
            )

            # girl texting
            registration_examples(
              keywords("KH", :girl, :could_mean_girl_or_girlfriend),
              :gender => :female,
              :looking_for => :female
            )
          end
        end

        context "friend" do
          # is already looking for a friend (gender unknown)
          before do
            user.looking_for = "e"
          end

          context "and the message is" do
            # guy texting
            registration_examples(
              keywords("KH", :boy, :could_mean_boy_or_boyfriend),
              :gender => :male,
              :looking_for => :either
            )

            # girl texting
            registration_examples(
              keywords("KH", :girl, :could_mean_girl_or_girlfriend),
              :gender => :female,
              :looking_for => :either
            )
          end
        end
      end

      context "new" do
        # user is new
        context "and the message is", :focus do
          # guy texting
          registration_examples(
            keywords("KH", :boy, :could_mean_boy_or_boyfriend),
            :gender => :male
          )

          # girl texting
          registration_examples(
            keywords("KH", :girl, :could_mean_girl_or_girlfriend),
            :gender => :female
          )

          # looking for a girl
          registration_examples(
            keywords("KH", :girlfriend),
            :looking_for => :female
          )

          # looking for a guy
          registration_examples(
            keywords("KH", :boyfriend),
            :looking_for => :male
          )

          # looking for a friend
          registration_examples(
            keywords("KH", :friend),
            :looking_for => :either
          )

          # guy looking for a girl
          registration_examples(
            keywords("KH", :guy_looking_for_a_girl),
            :gender => :male,
            :looking_for => :female
          )

          # girl looking for a guy
          registration_examples(
            keywords("KH", :girl_looking_for_a_guy),
            :gender => :female,
            :looking_for => :male
          )

          # guy looking for guy
          registration_examples(
            keywords("KH", :guy_looking_for_a_guy),
            :gender => :male,
            :looking_for => :male
          )

          # girl looking for girl
          registration_examples(
            keywords("KH", :girl_looking_for_a_girl),
            :gender => :female,
            :looking_for => :female
          )

          # guy looking for friend
          registration_examples(
            keywords("KH", :guy_looking_for_a_friend),
            :gender => :male,
            :looking_for => :either
          )

          # girl looking for friend
          registration_examples(
            keywords("KH", :girl_looking_for_a_friend),
            :gender => :female,
            :looking_for => :either
          )

          # guy named frank
          registration_examples(
            keywords("KH", :guy_named_frank),
            :name => "frank",
            :gender => :male
          )

          # girl named mara
          registration_examples(
            keywords("KH", :girl_named_mara),
            :name => "mara",
            :gender => :female
          )

          # 23 year old
          registration_examples(
            keywords("KH", :"23_year_old"),
            :age => 23
          )

          # Vichet 23 guy looking for a girl
          registration_examples(
            ["kjom Vichet pros 23chnam jong rok mit srey"],
            :gender => :male,
            :looking_for => :female,
            :age => 23,
            :name => "vichet"
          )
        end
      end
    end
  end
end
