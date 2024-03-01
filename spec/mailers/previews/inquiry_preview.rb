# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/inquiry
class InquiryPreview < ActionMailer::Preview
  def inquiry
    InquiryMailer.with(
      inquiry: Inquiry.general.order(:created_at).last
    ).inquiry
  end

  def setsu_inquiry
    InquiryMailer.with(
      inquiry: Inquiry.create(
        parent_name: '山田太郎',
        phone: '090-1234-5678',
        email: 'XkxZs@example.com',
        child_name: '田中',
        child_birthday: Date.new(2016, 4, 1),
        kindy: 'Okurayama',
        ele_school: '東京都立青山高等学校',
        start_date: Date.new(2016, 4, 1),
        requests: 'お疲れ様でした',
        category: 'R',
        school_id: 32,
        setsumeikai_id: Setsumeikai.first.id
      )
    ).setsu_inquiry
  end

  def online_setsu_inquiry
    InquiryMailer.with(
      inquiry: Inquiry.create(
        parent_name: '山田太郎',
        phone: '090-1234-5678',
        email: 'XkxZs@example.com',
        child_name: '田中',
        child_birthday: Date.new(2016, 4, 1),
        kindy: 'KidsDuo',
        ele_school: '東京都立青山高等学校',
        start_date: Date.new(2016, 4, 1),
        requests: 'お疲れ様でした',
        category: 'R',
        school_id: 2,
        setsumeikai_id: Setsumeikai.last.id
      )
    ).setsu_inquiry
  end
end
