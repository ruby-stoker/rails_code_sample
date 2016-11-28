# frozen_string_literal: true
class KeywordsController < ApplicationController
  include KeywordsHelper
  before_action :authenticate_user!
  before_action :check_mws_settings
  before_action :set_path, only: %i(tracking analysis matrix)
  before_action :set_product, only: %i(tracking analysis matrix update)
  before_action :set_products, only: %i(tracking analysis matrix)
  before_action :set_keywords, only: %i(analysis matrix)
  before_action :set_params_limit, only: %i(tracking analysis matrix)

  def tracking
    @keywords = @product.last_keyword_history.order(sort_column + ' ' + sort_direction)
    @history = @keywords.order(updated_at: :desc).last
    @suggestions = Rails.cache.fetch("keywords:suggestions:products:#{params[:id]}") || []
  end

  def analysis
  end

  def matrix
  end

  def update
    keywords = params[:keywords].split("\n").map(&:strip).map(&:downcase)
    @product.product_keywords.each do |product_keyword|
      if keywords.include? product_keyword.keyword
        keywords.delete(product_keyword.keyword)
      else
        product_keyword.destroy
      end
    end
    keywords.each do |keyword|
      product_keyword = @product.product_keywords.build
      product_keyword.keyword = keyword
      product_keyword.save
    end
    @product.reload
    @keywords = @product.product_keywords.order(id: :desc).page(params[:page]).per(params[:limit])
  end

  def refresh
    product = current_user.products.find_by(params[:id])
    product.product_keywords.each do |pk|
      KeywordTrackingJob.perform_later pk
    end
    flash[:info] = I18n.t('views.keywords.flash.info.refresh')
  end

  private

  def sort_column
    permitted_columns = ProductKeyword.column_names
    permitted_columns.push('keyword_histories.position', 'keyword_histories.page')
    permitted_columns.include?(params[:sort]) ? params[:sort] : 'id'
  end

  def sort_direction
    %w(asc desc).include?(params[:direction]) ? params[:direction] : 'asc'
  end

  protected

  def set_path
    @path = request.path
  end

  def set_params_limit
    params[:limit] ||= 12
  end

  def set_product
    @product = current_user.products.find(params[:id])
  end

  def set_products
    @products = current_user.products.page(params[:product_page]).per(params[:limit])
  end

  def set_keywords
    @keywords = @product.product_keywords.page(params[:keyword_page]).per(params[:limit])
  end
end
