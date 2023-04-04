# This file is last to simulate users who have just created an account

non_member = User.create!(
  email: 'non_member@gmail.com',
  password: 'nonmembernon',
  first_name: Faker::Name.first_name,
  family_name: Faker::Name.last_name,
  kana_first: Faker::Name.first_name,
  kana_family: Faker::Name.last_name,
  role: :customer,
  address: Faker::Address.full_address,
  phone: Faker::PhoneNumber.phone_number,
  school: School.all.find_by(name: '溝の口')
)

non_member.children.create!([
{
  first_name: Faker::Name.first_name,
  family_name: Faker::Name.last_name,
  kana_first: Faker::Name.first_name,
  kana_family: Faker::Name.last_name,
  en_name: %w[Timmy Sally Billy Sarah Viktoria Brett].sample,
  birthday: Faker::Date.birthday(min_age: 2, max_age: 13),
  ssid: Faker::Number.unique.number,
  ele_school_name: Faker::GreekPhilosophers.name,
  allergies: '',
  grade: '年中',
  category: :external,
  school: non_member.school
},
{
  first_name: Faker::Name.first_name,
  family_name: Faker::Name.last_name,
  kana_first: Faker::Name.first_name,
  kana_family: Faker::Name.last_name,
  en_name: %w[Timmy Sally Billy Sarah Viktoria Brett].sample,
  birthday: Faker::Date.birthday(min_age: 2, max_age: 13),
  ssid: Faker::Number.unique.number,
  ele_school_name: Faker::GreekPhilosophers.name,
  post_photos: true,
  allergies: '',
  grade: '小４',
  category: :external,
  school: non_member.school
}
])

member = User.create!(
  email: 'member@gmail.com',
  password: 'membermembermember',
  first_name: Faker::Name.first_name,
  family_name: Faker::Name.last_name,
  kana_first: Faker::Name.first_name,
  kana_family: Faker::Name.last_name,
  role: :customer,
  address: Faker::Address.full_address,
  phone: Faker::PhoneNumber.phone_number,
  school: School.all.find_by(name: '溝の口')
)

member.children.create!([
  {
    first_name: Faker::Name.first_name,
    family_name: Faker::Name.last_name,
    kana_first: Faker::Name.first_name,
    kana_family: Faker::Name.last_name,
    en_name: %w[Timmy Sally Billy Sarah Viktoria Brett].sample,
    birthday: Faker::Date.birthday(min_age: 2, max_age: 13),
    ssid: Faker::Number.unique.number,
    ele_school_name: Faker::GreekPhilosophers.name,
    post_photos: true,
    needs_hat: false,
    allergies: 'milk',
    grade: '年中',
    category: 'internal',
    school: member.school
  },
  {
    first_name: Faker::Name.first_name,
    family_name: Faker::Name.last_name,
    kana_first: Faker::Name.first_name,
    kana_family: Faker::Name.last_name,
    en_name: %w[Timmy Sally Billy Sarah Viktoria Brett].sample,
    birthday: Faker::Date.birthday(min_age: 2, max_age: 13),
    ssid: Faker::Number.unique.number,
    ele_school_name: Faker::GreekPhilosophers.name,
    needs_hat: false,
    allergies: 'milk',
    grade: '小４',
    category: 'internal',
    school: member.school
  }
])

member.children.each do |child|
child.create_regular_schedule!(
  monday: true,
  tuesday: false,
  wednesday: true,
  thursday: false,
  friday: false
)
end

puts 'Created test users and their children for only member children and only non-member children, with no registrations'