# frozen_string_literal: true

class MerchItemsController < ApplicationController
  include BlobFindable

  before_action :set_merch_item, only: %i[edit update destroy]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize MerchItem
    @merch_items = policy_scope(MerchItem).includes(:events).with_attached_image.with_attached_avif
  end

  def new
    @merch_item = authorize MerchItem.new
    @images = blobs_by_folder('merch_items')
  end

  def edit
    @images = blobs_by_folder('merch_items')
  end

  def create
    @merch_item = authorize MerchItem.new(merch_item_params)
    if @merch_item.save
      redirect_to merch_items_path, notice: "Created #{@merch_item.name}"
    else
      @images = blobs_by_folder('merch_items')
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @merch_item.update(merch_item_params)
      redirect_to merch_items_path, notice: "Updated #{@merch_item.name}"
    else
      @images = blobs_by_folder('merch_items')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @merch_item.destroy
    redirect_to merch_items_path, notice: 'Item deleted'
  end

  private

  def set_merch_item
    @merch_item = authorize MerchItem.find(params[:id])
  end

  def merch_item_params
    params.require(:merch_item).permit(
      :name, :cost, :stock, :sku, :closed, :close_at,
      :image, :avif, :description, :event_name
    )
  end
end
