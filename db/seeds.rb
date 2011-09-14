# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

user = User.find_or_create_by_mobile_number("85566998255")
user.name = "srey mao"
user.dob = 21.years.ago
user.sex = "m"
user.location = "Phnom Penh, Cambodia"
looking_for = "f"
user.rock
user.save!

user = User.find_or_create_by_mobile_number("855977100860")
user.dob = 24.years.ago
user.sex = "f"
user.location = "Phnom Penh, Cambodia"
looking_for = "m"
user.rock
user.save!

