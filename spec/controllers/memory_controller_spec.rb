require 'rails_helper'

RSpec.describe MemoryController, type: :controller do
  describe 'GET #index' do
    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns @stats with expected keys' do
      get :index
      stats = assigns(:stats)
      expect(stats).to include(:rss_bytes, :rss_mb, :heap_live_slots, :count_objects)
    end

    it 'returns JSON when requested' do
      get :index, format: :json
      expect(response).to have_http_status(:success)
      expect(response.content_type).to match(%r{application/json})
      json = JSON.parse(response.body)
      expect(json).to include('rss_bytes', 'rss_mb', 'heap_live_slots', 'count_objects')
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

  describe 'GET #object_stats' do
    it 'returns success as HTML' do
      get :object_stats
      expect(response).to have_http_status(:success)
    end

    it 'returns JSON when requested' do
      get :object_stats, format: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include('total_memsize', 'total_memsize_mb', 'by_count', 'by_size')
    end
  end
end
