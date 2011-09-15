require 'spec_helper'

describe "Recommendations" do
  include MessagingHelpers
  include TranslationHelpers

  let(:straight_girls) do
    create_list(:straight_female_registered_user, 4, :sex => "f")
  end

  context "Sok, is looking for a girl" do
    let(:sok) { create(:registered_user) }

    before do
      straight_girls
    end

    context "and is not chatting" do
      shared_examples_for "recommend sok some girls to chat with" do
        before do
          send_message(:from => sok, :body => message)
        end

        context "the reply" do
          let(:reply) { last_reply }

          it "should be sent to Sok" do
            reply.user.should == sok
          end

          it "should suggest Sok 4 straight girls to chat with" do
            usernames = straight_girls.map { |girl| girl.username }
            reply.body.should == spec_translate(
              :suggestions,
              :looking_for => sok.looking_for,
              :usernames => usernames
            )
          end
        end
      end

      context "sends the keyword 'meet'" do
        it_should_behave_like "recommend sok some girls to chat with" do
          let(:message) { "nhom chong meet srey" }
        end
      end

      context "sends the keyword 'met'" do
        it_should_behave_like "recommend sok some girls to chat with" do
          let(:message) { "nhom chong met srey" }
        end
      end

      context "sends the keyword 'find'" do
        it_should_behave_like "recommend sok some girls to chat with" do
          let(:message) { "nhom chong find srey" }
        end
      end
    end
  end
end

