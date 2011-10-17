require 'spec_helper'

def gender_examples(examples, options)
  gender = options[:gender]
  looking_for = options[:looking_for]

  examples.each do |message|
    check_gender_and_looking_for(message, gender, looking_for)
    check_gender_and_looking_for(message.upcase, gender, looking_for)
  end
end

def check_gender_and_looking_for(message, gender, looking_for)
  context "'#{message}'" do
    before do
      subject.user = user
      subject.body = message
      process_message
    end

    context "the user's" do
      context "gender" do
        if gender
          it "should be #{gender}" do
            user.should send("be_#{gender}")
          end
        else
          it "should be nil" do
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
    end
  end
end

describe SearchHandler do
  let(:user) do
    create(:user)
  end

  let(:user_with_complete_profile) do
    create(:user_with_complete_profile)
  end

  describe "#process!" do

    before do
      Timecop.freeze(Time.now)
    end

    after do
      Timecop.return
    end

    def process_message
      subject.process!
    end

    context "where the user is" do
      context "a guy" do
        before do
          user.update_attribute(:gender, "m")
        end

        shared_examples_for "a guy texting" do
          context "and the message is" do
            # looking for a guy
            gender_examples(
              ["bros", "pros", "boy"],
              :gender => :male,
              :looking_for => :male
            )

            # looking for a girl
            gender_examples(
              ["srey", "girl"],
              :gender => :male,
              :looking_for => :female
            )

            # looking for a friend
            gender_examples(
              ["friend", "met", "mit"],
              :gender => :male,
              :looking_for => :either
            )
          end
        end

        it_should_behave_like "a guy texting"

        context "and is looking for a" do
          context "guy" do
            before do
              user.update_attribute(:looking_for, "m")
            end

            it_should_behave_like "a guy texting"
          end

          context "girl" do
            before do
              user.update_attribute(:looking_for, "f")
            end

            it_should_behave_like "a guy texting"
          end

          context "friend" do
            before do
              user.update_attribute(:looking_for, "e")
            end

            it_should_behave_like "a guy texting"
          end
        end
      end

      context "a girl" do
        before do
          user.update_attribute(:gender, "f")
        end

        shared_examples_for "a girl texting" do
          context "and the message is" do
            # looking for a girl
            gender_examples(
              ["srey", "girl"],
              :gender => :female,
              :looking_for => :female
            )

            # looking for a guy
            gender_examples(
              ["bros", "pros", "boy"],
              :gender => :female,
              :looking_for => :male
            )

            # looking for a friend
            gender_examples(
              ["friend", "met", "mit"],
              :gender => :female,
              :looking_for => :either
            )
          end
        end

        it_should_behave_like "a girl texting"

        context "and is looking for a" do
          context "guy" do
            before do
              user.update_attribute(:looking_for, "m")
            end

            it_should_behave_like "a girl texting"
          end

          context "girl" do
            before do
              user.update_attribute(:looking_for, "f")
            end

            it_should_behave_like "a girl texting"
          end

          context "friend" do
            before do
              user.update_attribute(:looking_for, "e")
            end

            it_should_behave_like "a girl texting"
          end
        end
      end

      context "looking for a", :focus do
        context "guy" do
          before do
            user.update_attribute(:looking_for, "m")
          end

          context "and the message is" do
            # guy texting
            gender_examples(
              ["bros", "pros", "boy", "m", "male"],
              :gender => :male,
              :looking_for => :male
            )

            # girl texting
            gender_examples(
              ["srey", "girl", "f", "female"],
              :gender => :female,
              :looking_for => :male
            )
          end
        end

        context "girl" do
          before do
            user.update_attribute(:looking_for, "f")
          end

          context "and the message is" do
            # guy texting
            gender_examples(
              ["bros", "pros", "boy", "m", "male"],
              :gender => :male,
              :looking_for => :female
            )

            # girl texting
            gender_examples(
              ["srey", "girl", "f", "female"],
              :gender => :female,
              :looking_for => :female
            )
          end
        end

        context "friend" do
          before do
            user.update_attribute(:looking_for, "e")
          end

          context "and the message is" do
            # guy texting
            gender_examples(
              ["bros", "pros", "boy", "m", "male"],
              :gender => :male,
              :looking_for => :either
            )

            # girl texting
            gender_examples(
              ["srey", "girl", "f", "female"],
              :gender => :female,
              :looking_for => :either
            )
          end
        end
      end

      context "new" do
        context "and the message is" do
          # guy texting
          gender_examples(
            ["bros", "pros", "boy", "m", "male"],
            :gender => :male,
            :looking_for => nil
          )

          # girl texting
          gender_examples(
            ["srey", "girl", "f", "female"],
            :gender => :female,
            :looking_for => nil
          )

          # looking for a girl
          gender_examples(
            ["girl friend", "gf", "girlfriend", "friend girl", "met srey", "mit srey"],
            :gender => nil,
            :looking_for => :female
          )

          # looking for a guy
          gender_examples(
            ["boy friend" , "bf", "boyfriend", "friend boy", "met bros", "met pros", "mit bros", "mit pros"],
            :gender => nil,
            :looking_for => :male
          )

          # looking for a friend
          gender_examples(
            ["friend", "mit", "met"],
            :gender => nil,
            :looking_for => :either
          )

          # guy looking for a girl
          gender_examples(
            ["kjom bros jong rok mit srey", "asdfas asd m jab girl sweet", "sadf pros jaba asd srey cute"],
            :gender => :male,
            :looking_for => :female
          )

          # girl looking for a guy
          gender_examples(
            ["kunthia f pp blah bros saat nas", "nhom srey jong mian pros hot", "i girl want boy rich"],
            :gender => :female,
            :looking_for => :male
          )

          # guy looking for guy
          gender_examples(
            ["nhom bros jong rok mit bros", "bob m jong mian boy hot", "dsafds male jong pros"],
            :gender => :male,
            :looking_for => :male
          )

          # girl looking for girl
          gender_examples(
            ["nhom girl jong rok mit srey", "mara f jong mian girl for fun", "kunthia female jong mian srey cute"],
            :gender => :female,
            :looking_for => :female
          )

          # guy looking for friend
          gender_examples(
            ["nhom boy looking for friend to txt", "dave m jong rok met likes squash", "john bros rok mit funny"],
            :gender => :male,
            :looking_for => :either
          )

          # girl looking for friend
          gender_examples(
            ["nhom kunthia f looking for friend play txt", "mara srey jong rok met leng sms", "john female rok mit cute"],
            :gender => :female,
            :looking_for => :either
          )
        end
      end

      context "'kjom Vichet 23chnam phnom penh jong rok mit srey'" do
        def normalize_profile(new_profile_value)
          new_profile_value.is_a?(Proc) ? new_profile_value.call : new_profile_value
        end

        EXPECTED_NEW_PROFILE = {
          :name => "vichet",
          :date_of_birth => Proc.new{ || 23.years.ago.utc },
          :location => "phnom penh",
          :looking_for => "f"
        }

        shared_examples_for "update profile" do
          before do
            subject.user = user_in_context
            process_message
          end

          it "should set/update his profile" do
            user_in_context.send(new_profile_attribute).should == normalize_profile(new_profile_value)
          end
        end

        before do
          subject.body = "kjom Vichet 23chnam phnom penh jong rok mit srey"
        end

        EXPECTED_NEW_PROFILE.each do |attribute, value|
          context "a user" do
            context "with a complete profile" do
              it_should_behave_like "update profile" do
                let(:new_profile_attribute) { attribute }
                let(:new_profile_value) { value }
                let(:user_in_context) { user_with_complete_profile }
              end
            end

            context "with an incomplete profile" do
              context "(his #{attribute} is missing)" do
                it_should_behave_like "update profile" do
                  let(:new_profile_attribute) { attribute }
                  let(:new_profile_value) { value }
                  let(:user_in_context) { user }
                end
              end

              context "(his #{attribute} is already set)" do
                before do
                  subject.user = user
                  user.send("#{attribute}=", user_with_complete_profile.send(attribute))
                  process_message
                end

                it "should not update his #{attribute}" do
                  user.send(attribute).should_not == normalize_profile(value)
                end
              end
            end
          end
        end
      end
    end
  end
end

