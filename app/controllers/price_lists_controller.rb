# frozen_string_literal: true

class PriceListsController < ApplicationController
  def index
    @price_lists = authorize(PriceList.all)
  end

  def new
    @price_list = authorize(PriceList.new)
  end

  def edit
    @price_list = authorize(PriceList.find(params[:id]))
  end

  def create
    @price_list = authorize(PriceList.new(price_list_params))

    if @price_list.save
      redirect_to price_lists_path, notice: t('.success')
    else
      render :new, status: :unprocessable_entity, notice: t('.failure')
    end
  end

  def update
    @price_list = authorize(PriceList.find(params[:id]))

    if @price_list.update(price_list_params)
      redirect_to price_lists_path, notice: t('.success')
    else
      render :edit, status: :unprocessable_entity, notice: t('.failure')
    end
  end

  def destroy
    @price_list = authorize(PriceList.find(params[:id]))

    if @price_list.destroy
      redirect_to price_lists_path, notice: t('.success')
    else
      
    end
  end
end
