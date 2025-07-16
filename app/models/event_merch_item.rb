class EventMerchItem < ApplicationRecord
  belongs_to :event
  belongs_to :merch_item
end
