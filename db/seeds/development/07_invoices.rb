Child.all.find_each(batch_size: 100) do |child|
  child.invoices.create!([
    {
      event: child.school.events.first,
      total_cost: 0,
      billing_date: 1.year.from_now,
      in_ss: true
    },
    {
      event: child.school.events.first,
      total_cost: 0,
      billing_date: 6.months.from_now
    }
  ])
end

puts 'Created invoices for each child/event combo at each school'

Child.all.find_each(batch_size: 100) do |child|
  slots = child.school.events.first.time_slots.sample(10)

  slots.each do |slot|
    if slot.id.even?
      invoice = Invoice.find_by(child: child, in_ss: false)
      child.registrations.create!(registerable: slot, invoice: invoice)
      child.registrations.create!(registerable: slot.options.regular.last, invoice: invoice) unless slot.options.regular.empty?
      child.registrations.create!(registerable: slot.options.meal.last, invoice: invoice) unless slot.options.meal.empty?
    else
      invoice = Invoice.find_by(child: child, in_ss: true)
      child.registrations.create!(registerable: slot, invoice: invoice)
      child.registrations.create!(registerable: slot.options.arrival.last, invoice: invoice) unless slot.options.arrival.empty?
      child.registrations.create!(registerable: slot.options.departure.last, invoice: invoice) unless slot.options.departure.empty?
    end
  end
end

puts 'Registered children for 10 random time slots at their school and up to 2 options for each'

User.all.customer.select{|c| c.id.odd?}.each do |user|
  user.children.first.events.each do |event|
    user.children.first.registrations.create!(registerable: event.options.first, invoice: Invoice.find_by(child: user.children.first, event: event))
  end
end

puts "Registered a kid from every 2nd family for an event option"

Invoice.all.find_each(batch_size: 100) do |invoice|
  invoice.calc_cost
end

puts 'Calculated invoice costs and added to SS now all are created'