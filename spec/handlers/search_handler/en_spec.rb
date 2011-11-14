require 'spec_helper'

def registration_examples(examples, options)
  examples.each do |message|
    assert_user_attributes(message, options)
    assert_user_attributes(message.upcase, options) if message.present?
  end
end

def assert_user_attributes(message, options)
  new_options = options.dup
  gender = new_options.delete(:gender)
  looking_for = new_options.delete(:looking_for)
  location = new_options.delete(:location)

  context "'#{message}'" do
    before do
      subject.user = user
      subject.body = message
      Timecop.freeze(Time.now)
      process_message
    end

    after do
      Timecop.return
    end

    context "the user's" do
      context "gender" do
        if gender
          it "should be #{gender}" do
            user.should send("be_#{gender}")
          end
        else
          it "should be unknown" do
            user.gender.should be_nil
          end
        end
      end

      context "looking for" do
        if looking_for
          it "should be #{looking_for}" do
            user.looking_for.should == looking_for.to_s[0]
          end
        else
          it "should be unknown" do
            user.looking_for.should be_nil
          end
        end
      end

      context "location" do
        if location
          it "should be #{location}" do
            user.location.city.should == "Phnom Penh"
          end
        else
          it "should be unknown" do
            user.location.city.should be_nil
          end
        end
      end

      assert_generic_user_attributes(
        new_options.merge(:name => new_options[:name], :age => new_options[:age])
      )
    end
  end
end

def assert_generic_user_attributes(options)
  options.each do |attribute, value|
    context attribute do
      if value
        it "should be #{value}" do
          user.send(attribute).should == value
        end
      else
        it "should be unknown" do
          user.send(attribute).should be_nil
        end
      end
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
      # a guy texting
      context "a guy" do
        before do
          user.gender = "m"
        end

        shared_examples_for "a guy texting" do |looking_for|
          context "and the message is" do
            # a guy looking for a guy
            registration_examples(
              ["bros", "pros", "boy"],
              :gender => :male,
              :looking_for => :male
            )

            # a guy looking for a girl
            registration_examples(
              ["srey", "girl"],
              :gender => :male,
              :looking_for => :female
            )

            # a guy looking for a friend
            registration_examples(
              ["friend", "met", "mit"],
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
              ["srey", "girl"],
              :gender => :female,
              :looking_for => :female
            )

            # a girl looking for a guy
            registration_examples(
              ["bros", "pros", "boy"],
              :gender => :female,
              :looking_for => :male
            )

            # a girl looking for a friend
            registration_examples(
              ["friend", "met", "mit"],
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
              ["bros", "pros", "boy", "m", "male"],
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
#          # guy texting
#          registration_examples(
#            ["bros", "pros", "boy", "m", "male"],
#            :gender => :male,
#            :looking_for => nil
#          )

#          # girl texting
#          registration_examples(
#            ["srey", "girl", "f", "female"],
#            :gender => :female,
#            :looking_for => nil
#          )

#          # looking for a girl
#          registration_examples(
#            ["girl friend", "gf", "girlfriend", "friend girl", "met srey", "mit srey"],
#            :gender => nil,
#            :looking_for => :female
#          )

#          # looking for a guy
#          registration_examples(
#            ["boy friend" , "bf", "boyfriend", "friend boy", "met bros", "met pros", "mit bros", "mit pros"],
#            :gender => nil,
#            :looking_for => :male
#          )

#          # looking for a friend
#          registration_examples(
#            ["friend", "mit", "met"],
#            :gender => nil,
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

          # girl looking for friend
#          registration_examples(
#            ["nhom f looking for friend play txt", "srey jong rok met leng sms", "female rok mit cute"],
#            :gender => :female,
#            :looking_for => :either
#          )

          # frank
          registration_examples(
            ["nhom frank looking to play txt", "im frank mao jong leng sms", "i'm frank"],
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


