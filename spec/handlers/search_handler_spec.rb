require 'spec_helper'


def keywords(country_code, *keys)
  all_keywords = []
  keys.each do |key|
    english_keywords = SearchHandler.keywords["en"][key.to_s]
    localized_keywords = SearchHandler.keywords.try(:[], country_code.downcase).try(:[], key.to_s)
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

  context "'#{message}'" do
    before do
      subject.user = user
      subject.body = message
      subject.country_code = "KH"
      Timecop.freeze(Time.now)
      process_message
    end

    after do
      Timecop.return
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
      location ? user.location.city.should(eq("Phnom Penh")) : user.location.city.should(be_nil)
      name ? user.name.should(eq(name)) : user.name.should(be_nil)
      age ? user.age.should(eq(age)) : user.age.should(be_nil)
    end
  end
end

describe SearchHandler do
  let(:user) do
    build(:user)
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
              ["srey", "girl", "f", "female"],
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
              ["bros", "pros", "boy", "m", "male"],
              :gender => :male,
              :looking_for => :female
            )

            # girl texting
            registration_examples(
              ["srey", "girl", "f", "female"],
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
              ["bros", "pros", "boy", "m", "male"],
              :gender => :male,
              :looking_for => :either
            )

            # girl texting
            registration_examples(
              ["srey", "girl", "f", "female"],
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
#          registration_examples(
#            ["bros", "pros", "boy", "m", "male", "nhom pros jong leng sms"],
#            :gender => :male
#          )

#          # girl texting
#          registration_examples(
#            ["srey", "girl", "f", "female", "nhom srey jong leng sms"],
#            :gender => :female
#          )

#          # looking for a girl
#          registration_examples(
#            ["girl friend", "gf", "girlfriend", "friend girl", "met srey", "mit srey"],
#            :looking_for => :female
#          )

#          # looking for a guy
#          registration_examples(
#            ["boy friend" , "bf", "boyfriend", "friend boy", "met bros", "met pros", "mit bros", "mit pros"],
#            :looking_for => :male
#          )

#          # looking for a friend
#          registration_examples(
#            ["friend", "mit", "met"],
#            :looking_for => :either
#          )

#          # guy looking for a girl
#          registration_examples(
#            ["bros jong rok mit srey", "m jab girl sweet", "pros jaba asd srey cute"],
#            :gender => :male,
#            :looking_for => :female
#          )

#          # girl looking for a guy
#          registration_examples(
#            ["f blah bros saat nas", "nhom srey jong mian pros hot", "i girl want boy rich"],
#            :gender => :female,
#            :looking_for => :male
#          )

#          # guy looking for guy
#          registration_examples(
#            ["nhom bros jong rok mit bros", "m jong mian boy hot", "guy jong pros"],
#            :gender => :male,
#            :looking_for => :male
#          )

#          # girl looking for girl
#          registration_examples(
#            ["nhom girl jong rok mit srey", "f jong mian girl for fun", "female jong mian srey cute"],
#            :gender => :female,
#            :looking_for => :female
#          )

#          # guy looking for friend
#          registration_examples(
#            ["nhom boy looking for friend to txt", "m jong rok met likes squash", "bros rok mit funny"],
#            :gender => :male,
#            :looking_for => :either
#          )

#          # girl looking for friend
#          registration_examples(
#            ["nhom f looking for friend play txt", "srey jong rok met leng sms", "female rok mit cute"],
#            :gender => :female,
#            :looking_for => :either
#          )

          # frank
          registration_examples(
            ["nhom frank looking to play txt", "im frank mao jong leng sms", "i'm frank", "i am frank"],
            :name => "frank"
          )

          # Vichet 23 guy looking for a girl
#          registration_examples(
#            ["kjom Vichet pros 23chnam jong rok mit srey", "Vichet bros 23 phnom penh srey sexy"],
#            :gender => :male,
#            :looking_for => :female,
#            :age => 23,
#            :name => "vichet"
#          )
        end
      end
    end
  end
end



