User.customers.each do |customer|
  next unless customer.children.empty?
  
  customer.children.create!([
    {
      first_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      family_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      kana_first: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      kana_family: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      en_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      birthday: 'Fri, 21 Aug 2020',
      ssid: "#{customer.id}#{customer.school_id}1".to_i,
      ele_school_name: '菊名',
      post_photos: true,
      allergies: 'なし',
      grade: '年中',
      category: :external,
      school: customer.school
    },
    {
      first_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      family_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      kana_first: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      kana_family: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      en_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
      birthday: 'Fri, 21 Aug 2020',
      ssid: "#{customer.id}#{customer.school_id}2".to_i,
      ele_school_name: '菊名',
      allergies: 'peanuts',
      grade: '小４',
      category: :reservation,
      school: customer.school
    }
  ])
end

Child.create!(
  first_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
  family_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
  kana_first: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
  kana_family: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
  en_name: %w[Timmy Sally Billy Sarah Brett ヨシ マリナ カイト].sample,
  birthday: 'Wed, 20 Feb 2020',
  ssid: 9999999999999,
  ele_school_name: '菊名',
  allergies: 'peanuts',
  grade: '小４'
)

Child.all.each do |child|
  next unless child.regular_schedule.nil?

  child.create_regular_schedule(
    monday: [true, false].sample,
    tuesday: [true, false].sample,
    wednesday: [true, false].sample,
    thursday: [true, false].sample,
    friday: [true, false].sample
  )
end