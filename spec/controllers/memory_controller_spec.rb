require 'rails_helper'

RSpec.describe MemoryController, type: :controller do
  describe 'GET #index' do
    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns merged stats with measured heap' do
      get :index
      stats = assigns(:stats)
      expect(stats).to include(:rss_bytes, :rss_mb, :heap_live_slots, :heap_measured_mb, :top_by_count, :top_by_size)
    end

    it 'returns JSON when requested' do
      get :index, format: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include('rss_bytes', 'rss_mb', 'heap_measured_mb', 'top_by_count', 'top_by_size')
    end
  end

  describe 'GET #fast' do
    it 'returns success' do
      get :fast
      expect(response).to have_http_status(:success)
    end

    it 'assigns fast stats with count_objects' do
      get :fast
      stats = assigns(:stats)
      expect(stats).to include(:rss_bytes, :rss_mb, :heap_live_slots, :count_objects)
      expect(stats).not_to have_key(:top_by_count)
    end

    it 'returns JSON when requested' do
      get :fast, format: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include('rss_bytes', 'count_objects')
    end
  end

  describe 'POST #run_gc' do
    it 'returns JSON with before/after RSS and stats' do
      post :run_gc
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include('before_rss', 'after_rss', 'freed', 'stats')
    end
  end

  describe 'POST #malloc_trim' do
    it 'returns JSON with before/after RSS and stats' do
      post :malloc_trim
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include('before_rss', 'after_rss', 'freed', 'trimmed', 'stats')
    end
  end
end
