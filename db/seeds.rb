# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

user = User.find_or_create_by_mobile_number("85566998255")
user.name = "srey mao"
user.date_of_birth = 21.years.ago
user.gender = "f"
user.location = "Phnom Penh, Cambodia"
looking_for = "f"
user.save!

user = User.find_or_create_by_mobile_number("855977100860")
user.name = "bong dave"
user.date_of_birth = 24.years.ago
user.gender = "m"
user.location = "Phnom Penh, Cambodia"
looking_for = "f"
user.save!

user = User.find_or_create_by_mobile_number("85566818266")
user.name = "oun mara"
user.date_of_birth = 26.years.ago
user.gender = "f"
user.location = "Battambang, Cambodia"
looking_for = "f"
user.save!

