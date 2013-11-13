# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20131113063908) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "call_data_records", force: true do |t|
    t.text     "body"
    t.string   "uuid"
    t.integer  "duration"
    t.integer  "bill_sec"
    t.datetime "rfc2822_date"
    t.string   "direction"
    t.integer  "phone_call_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.string   "type"
    t.integer  "inbound_cdr_id"
    t.string   "bridge_uuid"
    t.string   "from"
    t.integer  "user_id"
    t.string   "cdr_data"
  end

  add_index "call_data_records", ["bridge_uuid"], name: "index_call_data_records_on_bridge_uuid", using: :btree
  add_index "call_data_records", ["direction"], name: "index_call_data_records_on_direction", using: :btree
  add_index "call_data_records", ["from"], name: "index_call_data_records_on_from", using: :btree
  add_index "call_data_records", ["inbound_cdr_id"], name: "index_call_data_records_on_inbound_cdr_id", using: :btree
  add_index "call_data_records", ["phone_call_id", "type"], name: "index_call_data_records_on_phone_call_id_and_type", unique: true, using: :btree
  add_index "call_data_records", ["user_id"], name: "index_call_data_records_on_user_id", using: :btree
  add_index "call_data_records", ["uuid"], name: "index_call_data_records_on_uuid", unique: true, using: :btree

  create_table "charge_requests", force: true do |t|
    t.string   "result"
    t.string   "reason"
    t.string   "state"
    t.string   "operator"
    t.boolean  "notify_requester", default: false, null: false
    t.integer  "requester_id"
    t.string   "requester_type"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "charge_requests", ["requester_type", "requester_id"], name: "index_charge_requests_on_requester_type_and_requester_id", using: :btree
  add_index "charge_requests", ["updated_at", "state"], name: "index_charge_requests_on_updated_at_and_state", using: :btree
  add_index "charge_requests", ["user_id"], name: "index_charge_requests_on_user_id", using: :btree

  create_table "chats", force: true do |t|
    t.integer  "user_id"
    t.integer  "friend_id"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.integer  "starter_id"
    t.string   "starter_type"
  end

  add_index "chats", ["friend_id"], name: "index_chats_on_friend_id", using: :btree
  add_index "chats", ["starter_type", "starter_id"], name: "index_chats_on_starter_type_and_starter_id", using: :btree
  add_index "chats", ["updated_at"], name: "index_chats_on_updated_at", using: :btree
  add_index "chats", ["user_id", "friend_id"], name: "index_chats_on_user_id_and_friend_id", unique: true, using: :btree
  add_index "chats", ["user_id"], name: "index_chats_on_user_id", using: :btree

  create_table "locations", force: true do |t|
    t.string   "city"
    t.string   "country_code", limit: 2
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "user_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "locations", ["country_code"], name: "index_locations_on_country_code", using: :btree
  add_index "locations", ["user_id"], name: "index_locations_on_user_id", using: :btree

  create_table "messages", force: true do |t|
    t.string   "from"
    t.text     "body"
    t.integer  "user_id"
    t.integer  "chat_id"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "guid"
    t.string   "state",      default: "received", null: false
  end

  add_index "messages", ["chat_id"], name: "index_messages_on_chat_id", using: :btree
  add_index "messages", ["guid"], name: "index_messages_on_guid", unique: true, using: :btree
  add_index "messages", ["state"], name: "index_messages_on_state", using: :btree
  add_index "messages", ["user_id"], name: "index_messages_on_user_id", using: :btree

  create_table "missed_calls", force: true do |t|
    t.string   "from"
    t.integer  "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "missed_calls", ["user_id"], name: "index_missed_calls_on_user_id", using: :btree

  create_table "phone_calls", force: true do |t|
    t.string   "sid"
    t.string   "from"
    t.string   "state"
    t.integer  "user_id"
    t.integer  "chat_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.string   "dial_call_sid"
  end

  add_index "phone_calls", ["chat_id"], name: "index_phone_calls_on_chat_id", using: :btree
  add_index "phone_calls", ["dial_call_sid"], name: "index_phone_calls_on_dial_call_sid", unique: true, using: :btree
  add_index "phone_calls", ["sid"], name: "index_phone_calls_on_sid", unique: true, using: :btree
  add_index "phone_calls", ["state"], name: "index_phone_calls_on_state", using: :btree
  add_index "phone_calls", ["user_id"], name: "index_phone_calls_on_user_id", using: :btree

  create_table "replies", force: true do |t|
    t.string   "to"
    t.text     "body"
    t.integer  "user_id"
    t.integer  "chat_id"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.datetime "delivered_at"
    t.string   "token"
    t.string   "state",        default: "pending_delivery", null: false
  end

  add_index "replies", ["chat_id"], name: "index_replies_on_chat_id", using: :btree
  add_index "replies", ["state"], name: "index_replies_on_state", using: :btree
  add_index "replies", ["token"], name: "index_replies_on_token", unique: true, using: :btree
  add_index "replies", ["user_id"], name: "index_replies_on_user_id", using: :btree

  create_table "users", force: true do |t|
    t.string   "mobile_number"
    t.string   "name"
    t.string   "screen_name"
    t.date     "date_of_birth"
    t.string   "gender",                   limit: 1
    t.string   "looking_for",              limit: 1
    t.integer  "active_chat_id"
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
    t.string   "state",                              default: "online", null: false
    t.datetime "last_interacted_at"
    t.datetime "last_contacted_at"
    t.datetime "activated_at"
    t.string   "operator_name"
    t.integer  "latest_charge_request_id"
  end

  add_index "users", ["active_chat_id"], name: "index_users_on_active_chat_id", using: :btree
  add_index "users", ["date_of_birth"], name: "index_users_on_date_of_birth", using: :btree
  add_index "users", ["gender"], name: "index_users_on_gender", using: :btree
  add_index "users", ["latest_charge_request_id"], name: "index_users_on_latest_charge_request_id", using: :btree
  add_index "users", ["looking_for"], name: "index_users_on_looking_for", using: :btree
  add_index "users", ["mobile_number"], name: "index_users_on_mobile_number", unique: true, using: :btree
  add_index "users", ["operator_name"], name: "index_users_on_operator_name", using: :btree
  add_index "users", ["state"], name: "index_users_on_state", using: :btree

end
