require 'spec_helper'

describe "Recommendations" do
  #include MessagingHelpers
  include TranslationHelpers

  let(:girls_looking_for_boys) do
    create_list(:girl_looking_for_guy, 4)
  end

  let(:sok) { create(:guy_looking_for_girl) }
  let(:account) { create :account }

  context "Sok, is looking for a girl" do
    before do
      girls_looking_for_boys
    end

    context "and is not chatting" do
      shared_examples_for "recommend sok some girls to chat with" do
        before do
          post messages_path,
          {:from => sok.mobile_number, :body => message_text},
          {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(account.username, "foobar")}
        end

        context "the last message" do
          let(:last_message) { Message.last }

          it "should have a reply" do
            last_message.reply.should be_present
          end

          context "reply" do
            let(:reply) { last_message.reply }

            it "should be sent to Sok" do
              reply.subscription.user.should == sok
            end

            it "should suggest Sok 4 straight girls to chat with" do
              usernames = girls_looking_for_boys.map { |girl| girl.username }
              reply.body.should == spec_translate(
                :suggestions,
                :looking_for => sok.looking_for,
                :usernames => usernames
              )
            end

            it "should not suggest Sok to chat with himself" do
              reply.body.should_not include(sok.username)
            end
          end
        end
      end

      context "sends the keyword 'meet'" do
        it_should_behave_like "recommend sok some girls to chat with" do
          let(:message_text) { "nhom chong meet srey" }
        end
      end

      context "sends the keyword 'met'" do
        it_should_behave_like "recommend sok some girls to chat with" do
          let(:message_text) { "nhom chong met srey" }
        end
      end

      context "sends the keyword 'find'" do
        it_should_behave_like "recommend sok some girls to chat with" do
          let(:message_text) { "nhom chong find srey" }
        end
      end
    end
  end
end

