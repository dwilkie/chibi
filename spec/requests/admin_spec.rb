require 'spec_helper'

describe "Admin" do
  include MessagingHelpers

  let(:user) { create(:user) }
  let(:another_user) { create(:user) }

  let(:message) { create(:message, :user => user, :body => "Hello") }
  let(:another_message) { create(:message, :user => user, :body => "Goodbye") }

  let(:reply) { expect_message { create(:reply, :user => user, :body => "Hello") } }
  let(:another_reply) { expect_message { create(:reply, :user => user, :body => "Goodbye") } }

  let(:chat) { create(:chat, :user => user, :created_at => 10.minutes.ago) }
  let(:another_chat) { create(:active_chat, :user => another_user, :friend => user, :created_at => 10.minutes.ago) }

  let(:message_from_another_user) { create(:message, :user => another_user) }
  let(:reply_to_another_user) {  expect_message { create(:reply, :user => another_user) } }

  let(:users) { [another_user, user] }
  let(:messages) { [message, another_message] }
  let(:replies) { [reply, another_reply] }
  let(:chats) { [chat, another_chat] }

  context "as an admin" do
    before do
      page.driver.browser.basic_authorize(
        ENV["HTTP_BASIC_AUTH_ADMIN_USER"], ENV["HTTP_BASIC_AUTH_ADMIN_PASSWORD"]
      )
    end

    def assert_index(resource_name, options = {})
      resources = send(resource_name.to_s.pluralize)
      resources.reverse! if options[:reverse]

      page.should have_content resources.count

      resources.each_with_index do |resource, index|
        within("##{resource_name}_#{index + 1}") do
          send("assert_#{resource_name}_show", resource)
        end
      end
    end

    def assert_user_show(reference_user)
      page.should have_content reference_user.id
      page.should have_content reference_user.screen_name
      page.should have_content reference_user.online
      page.should have_content reference_user.mobile_number
    end

    def assert_message_show(reference_message)
      page.should have_content reference_message.body
      page.should have_content reference_message.from
    end

    def assert_reply_show(reference_reply)
      page.should have_content reference_reply.body
      page.should have_content reference_reply.to
    end

    def assert_chat_show(reference_chat)
      page.should have_content "10 minutes ago"
      page.should have_content reference_chat.active?
      page.should have_link("initiator")
      page.should have_link("partner")
    end

    shared_examples_for "showing a user" do
      it "should show me the user" do
        page.current_path.should == user_path(reference_user)
        page.should have_content reference_user.screen_id
      end
    end

    context "given some chats" do
      before do
        chats
      end

      context "when I visit '/chats'" do
        before do
          visit chats_path
        end

        it "should show me a list of chats" do
          assert_index :chat, :reverse => true
        end

        context "when I click on the 'initiator' link for one of the chats" do
          before do
            within("#chat_1") do
              click_link("initiator")
            end
          end

          it_should_behave_like "showing a user" do
            let(:reference_user) { another_user }
          end
        end

        context "when I click on the 'partner' link for one of the chats" do
          before do
            within("#chat_1") do
              click_link("partner")
            end
          end

          it_should_behave_like "showing a user" do
            let(:reference_user) { user }
          end
        end
      end
    end

    context "given some messages" do
      before do
        messages
      end

      context "when I visit '/messages'" do
        before do
          visit messages_path
        end

        it "should show me a list of messages" do
          assert_index :message
        end
      end
    end

    context "given some replies" do
      before do
        replies
      end

      context "when I visit '/replies'" do
        before do
          visit replies_path
        end

        it "should show me a list of replies" do
          assert_index :reply, :reverse => true
        end
      end
    end

    context "given some users" do
      before do
        users
      end

      context "when I visit '/users'" do
        before do
          visit users_path
        end

        it "should show me a list of users" do
          assert_index :user, :reverse => true
        end

        context "when I click on 'X' for one of the users" do
          before do
            within("#user_1") do
              click_link("X")
            end
          end

          it "should delete the user" do
            within("#user_1") do
              page.should have_content another_user.id
            end

            page.should have_no_css "#user_2"
          end
        end

        context "when I click on 'show' for one of the users" do

          before do
            within("#user_1") do
              click_link("show")
            end
          end

          it_should_behave_like "showing a user" do
            let(:reference_user) { user }
          end

          context "given they been sent some replies" do
            before do
              replies
              reply_to_another_user
            end

            context "when I click 'replies'" do
              before do
                click_link("replies")
              end

              it "should show me the replies sent to this user" do
                assert_index :reply, :reverse => true
              end

              context "when I click on the mobile number for the reply" do
                before do
                  within("#reply_1") do
                    click_link(reply.to)
                  end
                end

                it_should_behave_like "showing a user" do
                  let(:reference_user) { user }
                end
              end
            end
          end

          context "given they have sent some messages" do
            before do
              messages
              message_from_another_user
            end

            context "when I click 'messages'" do
              before do
                click_link("messages")
              end

              it "should show me the messages from this user" do
                assert_index :message
              end

              context "when I click on the mobile number for the message" do
                before do
                  within("#message_1") do
                    click_link(message.from)
                  end
                end

                it_should_behave_like "showing a user" do
                  let(:reference_user) { user }
                end
              end
            end
          end
        end
      end
    end
  end
end
