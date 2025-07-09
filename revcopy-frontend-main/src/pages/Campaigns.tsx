import React, { useState, useEffect } from 'react';
import { api, handleApiError } from '../lib/api';
import { toast } from 'sonner';
import { 
  Copy, 
  Loader2, 
  Calendar, 
  Type, 
  Globe, 
  Hash, 
  Plus, 
  Edit, 
  Trash2, 
  Save, 
  X,
  Search,
  Filter,
  MoreHorizontal,
  Eye,
  Download,
  Share2,
  Star,
  TrendingUp,
  Users,
  Target
} from 'lucide-react';
import Sidebar from '../components/Sidebar';

interface Campaign {
  id: number;
  name: string;
  description?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  content: Array<{
    id: number;
    content_type: string;
    title: string;
    content: string;
    word_count: number;
    character_count: number;
    language: string;
    created_at: string;
    status: string;
  }>;
}

interface CampaignFormData {
  name: string;
  description?: string;
}

const Campaigns = () => {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isCreating, setIsCreating] = useState(false);
  const [editingCampaign, setEditingCampaign] = useState<number | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState<'all' | 'active' | 'inactive'>('all');
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [formData, setFormData] = useState<CampaignFormData>({ name: '', description: '' });

  useEffect(() => {
    loadCampaigns();
  }, []);

  const loadCampaigns = async () => {
    try {
      setIsLoading(true);
      const response = await api.campaigns.getCampaigns();
      
      if (response.success && response.data) {
        setCampaigns(response.data);
      } else {
        console.log('No campaigns found or error:', response.error);
        setCampaigns([]);
      }
    } catch (error) {
      console.error('Failed to load campaigns:', error);
      setCampaigns([]);
    } finally {
      setIsLoading(false);
    }
  };

  const createCampaign = async (data: CampaignFormData) => {
    try {
      setIsCreating(true);
      const response = await api.campaigns.createCampaign(data);
      
      if (response.success) {
        toast.success('Campaign created successfully!');
        setShowCreateForm(false);
        setFormData({ name: '', description: '' });
        loadCampaigns();
      } else {
        throw new Error(response.error || 'Failed to create campaign');
      }
    } catch (error) {
      console.error('Failed to create campaign:', error);
      const errorMessage = handleApiError(error);
      toast.error(`Failed to create campaign: ${errorMessage}`);
    } finally {
      setIsCreating(false);
    }
  };

  const updateCampaign = async (campaignId: number, data: CampaignFormData) => {
    try {
      const response = await api.campaigns.updateCampaign(campaignId, data);
      
      if (response.success) {
        toast.success('Campaign updated successfully!');
        setEditingCampaign(null);
        loadCampaigns();
      } else {
        throw new Error(response.error || 'Failed to update campaign');
      }
    } catch (error) {
      console.error('Failed to update campaign:', error);
      const errorMessage = handleApiError(error);
      toast.error(`Failed to update campaign: ${errorMessage}`);
    }
  };

  const deleteCampaign = async (campaignId: number) => {
    if (!confirm('Are you sure you want to delete this campaign? This action cannot be undone.')) {
      return;
    }

    try {
      const response = await api.campaigns.deleteCampaign(campaignId);
      
      if (response.success) {
        toast.success('Campaign deleted successfully!');
        loadCampaigns();
      } else {
        throw new Error(response.error || 'Failed to delete campaign');
      }
    } catch (error) {
      console.error('Failed to delete campaign:', error);
      const errorMessage = handleApiError(error);
      toast.error(`Failed to delete campaign: ${errorMessage}`);
    }
  };

  const copyContent = async (content: string) => {
    try {
      await navigator.clipboard.writeText(content);
      toast.success('Content copied to clipboard!');
    } catch (error) {
      toast.error('Failed to copy content');
    }
  };

  const formatDate = (dateString: string) => {
    try {
      return new Date(dateString).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      });
    } catch {
      return 'Unknown date';
    }
  };

  const getContentTypeIcon = (contentType: string) => {
    const icons: Record<string, React.ReactNode> = {
      'facebook_ad': <TrendingUp className="w-4 h-4" />,
      'instagram_caption': <Globe className="w-4 h-4" />,
      'google_ad': <Target className="w-4 h-4" />,
      'blog_article': <Type className="w-4 h-4" />,
      'email_campaign': <Users className="w-4 h-4" />,
      'product_description': <Star className="w-4 h-4" />
    };
    return icons[contentType] || <Type className="w-4 h-4" />;
  };

  const filteredCampaigns = campaigns.filter(campaign => {
    const matchesSearch = campaign.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         campaign.description?.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesFilter = filterStatus === 'all' || 
                         (filterStatus === 'active' && campaign.is_active) ||
                         (filterStatus === 'inactive' && !campaign.is_active);
    return matchesSearch && matchesFilter;
  });

  const handleCreateSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      toast.error('Campaign name is required');
      return;
    }
    createCampaign(formData);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#FDFDFD] flex">
        <Sidebar />
        <main className="flex-1 p-8">
          <div className="max-w-7xl mx-auto">
            <div className="flex items-center justify-center h-64">
              <Loader2 className="w-8 h-8 animate-spin text-purple-600" />
              <span className="ml-2 text-gray-600">Loading campaigns...</span>
            </div>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#FDFDFD] flex">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="flex items-center justify-between mb-8">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Campaigns</h1>
              <p className="text-gray-600 mt-1">Manage your marketing campaigns and content</p>
            </div>
            <button
              onClick={() => setShowCreateForm(true)}
              className="inline-flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
            >
              <Plus className="w-4 h-4 mr-2" />
              New Campaign
            </button>
          </div>

          {/* Search and Filters */}
          <div className="flex items-center space-x-4 mb-6">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
              <input
                type="text"
                placeholder="Search campaigns..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              />
            </div>
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value as any)}
              className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            >
              <option value="all">All Campaigns</option>
              <option value="active">Active Only</option>
              <option value="inactive">Inactive Only</option>
            </select>
          </div>

          {/* Create Campaign Form */}
          {showCreateForm && (
            <div className="bg-white rounded-lg shadow-sm border p-6 mb-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-gray-900">Create New Campaign</h3>
                <button
                  onClick={() => {
                    setShowCreateForm(false);
                    setFormData({ name: '', description: '' });
                  }}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              <form onSubmit={handleCreateSubmit}>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Campaign Name *
                    </label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                      placeholder="Enter campaign name"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Description
                    </label>
                    <textarea
                      value={formData.description}
                      onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                      placeholder="Enter campaign description"
                      rows={3}
                    />
                  </div>
                  <div className="flex items-center space-x-3">
                    <button
                      type="submit"
                      disabled={isCreating}
                      className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {isCreating ? (
                        <>
                          <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                          Creating...
                        </>
                      ) : (
                        <>
                          <Save className="w-4 h-4 mr-2" />
                          Create Campaign
                        </>
                      )}
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setShowCreateForm(false);
                        setFormData({ name: '', description: '' });
                      }}
                      className="px-4 py-2 text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </form>
            </div>
          )}

          {/* Campaigns Grid */}
          {filteredCampaigns.length === 0 ? (
            <div className="bg-white rounded-lg shadow-sm border p-12 text-center">
              <Hash className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                {searchTerm || filterStatus !== 'all' ? 'No campaigns found' : 'No campaigns yet'}
              </h3>
              <p className="text-gray-600 mb-4">
                {searchTerm || filterStatus !== 'all' 
                  ? 'Try adjusting your search or filters.'
                  : 'Start by creating your first campaign to organize your content.'
                }
              </p>
              {!searchTerm && filterStatus === 'all' && (
                <button
                  onClick={() => setShowCreateForm(true)}
                  className="inline-flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
                >
                  <Plus className="w-4 h-4 mr-2" />
                  Create Your First Campaign
                </button>
              )}
            </div>
          ) : (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {filteredCampaigns.map((campaign) => (
                <div
                  key={campaign.id}
                  className="bg-white rounded-lg shadow-sm border hover:shadow-md transition-shadow"
                >
                  <div className="p-6">
                    {/* Campaign Header */}
                    <div className="flex items-start justify-between mb-4">
                      <div className="flex-1">
                        {editingCampaign === campaign.id ? (
                          <div className="space-y-3">
                            <input
                              type="text"
                              defaultValue={campaign.name}
                              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
                              onKeyDown={(e) => {
                                if (e.key === 'Enter') {
                                  const newName = e.currentTarget.value;
                                  updateCampaign(campaign.id, { name: newName, description: campaign.description });
                                }
                              }}
                              autoFocus
                            />
                            <textarea
                              defaultValue={campaign.description}
                              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
                              rows={2}
                              placeholder="Campaign description"
                            />
                            <div className="flex space-x-2">
                              <button
                                onClick={() => {
                                  const nameInput = document.querySelector(`input[data-campaign-id="${campaign.id}"]`) as HTMLInputElement;
                                  const descInput = document.querySelector(`textarea[data-campaign-id="${campaign.id}"]`) as HTMLTextAreaElement;
                                  updateCampaign(campaign.id, { 
                                    name: nameInput?.value || campaign.name, 
                                    description: descInput?.value || campaign.description 
                                  });
                                }}
                                className="px-3 py-1 bg-purple-600 text-white rounded text-sm hover:bg-purple-700"
                              >
                                Save
                              </button>
                              <button
                                onClick={() => setEditingCampaign(null)}
                                className="px-3 py-1 text-gray-600 border border-gray-300 rounded text-sm hover:bg-gray-50"
                              >
                                Cancel
                              </button>
                            </div>
                          </div>
                        ) : (
                          <div>
                            <h3 className="text-lg font-semibold text-gray-900 mb-1">
                              {campaign.name}
                            </h3>
                            {campaign.description && (
                              <p className="text-sm text-gray-600">{campaign.description}</p>
                            )}
                          </div>
                        )}
                      </div>
                      <div className="flex items-center space-x-2">
                        <div className={`px-2 py-1 rounded-full text-xs font-medium ${
                          campaign.is_active 
                            ? 'bg-green-100 text-green-800' 
                            : 'bg-gray-100 text-gray-800'
                        }`}>
                          {campaign.is_active ? 'Active' : 'Inactive'}
                        </div>
                        {editingCampaign !== campaign.id && (
                          <div className="relative">
                            <button className="text-gray-400 hover:text-gray-600 p-1">
                              <MoreHorizontal className="w-4 h-4" />
                            </button>
                            <div className="absolute right-0 top-8 bg-white border border-gray-200 rounded-lg shadow-lg py-1 z-10 min-w-[120px]">
                              <button
                                onClick={() => setEditingCampaign(campaign.id)}
                                className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center"
                              >
                                <Edit className="w-4 h-4 mr-2" />
                                Edit
                              </button>
                              <button
                                onClick={() => deleteCampaign(campaign.id)}
                                className="w-full px-3 py-2 text-left text-sm text-red-600 hover:bg-gray-50 flex items-center"
                              >
                                <Trash2 className="w-4 h-4 mr-2" />
                                Delete
                              </button>
                            </div>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Campaign Stats */}
                    <div className="flex items-center space-x-4 text-sm text-gray-500 mb-4">
                      <div className="flex items-center">
                        <Calendar className="w-4 h-4 mr-1" />
                        Created {formatDate(campaign.created_at)}
                      </div>
                      <div className="flex items-center">
                        <Type className="w-4 h-4 mr-1" />
                        {campaign.content.length} content pieces
                      </div>
                    </div>

                    {/* Content Preview */}
                    {campaign.content.length > 0 && (
                      <div className="border-t pt-4">
                        <h4 className="text-sm font-medium text-gray-900 mb-3">Recent Content</h4>
                        <div className="space-y-3">
                          {campaign.content.slice(0, 3).map((content) => (
                            <div
                              key={content.id}
                              className="border rounded-lg p-3 hover:bg-gray-50 transition-colors"
                            >
                              <div className="flex items-start justify-between mb-2">
                                <div className="flex items-center space-x-2">
                                  <span className="text-purple-600">
                                    {getContentTypeIcon(content.content_type)}
                                  </span>
                                  <span className="px-2 py-1 bg-purple-100 text-purple-800 rounded text-xs font-medium">
                                    {content.content_type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                                  </span>
                                  <span className="text-xs text-gray-500">
                                    {content.word_count} words
                                  </span>
                                </div>
                                <div className="flex items-center space-x-1">
                                  <button
                                    onClick={() => copyContent(content.content)}
                                    className="text-gray-400 hover:text-gray-600 transition-colors p-1"
                                    title="Copy content"
                                  >
                                    <Copy className="w-4 h-4" />
                                  </button>
                                  <button className="text-gray-400 hover:text-gray-600 transition-colors p-1" title="View">
                                    <Eye className="w-4 h-4" />
                                  </button>
                                  <button className="text-gray-400 hover:text-gray-600 transition-colors p-1" title="Download">
                                    <Download className="w-4 h-4" />
                                  </button>
                                </div>
                              </div>
                              <p className="text-sm text-gray-700 line-clamp-2">
                                {content.content.substring(0, 150)}...
                              </p>
                              <div className="flex items-center justify-between mt-2">
                                <div className="flex items-center space-x-2 text-xs text-gray-500">
                                  <Globe className="w-3 h-3" />
                                  <span>{content.language.toUpperCase()}</span>
                                </div>
                                <span className="text-xs text-gray-500">
                                  {formatDate(content.created_at)}
                                </span>
                              </div>
                            </div>
                          ))}
                        </div>
                        {campaign.content.length > 3 && (
                          <div className="mt-3 text-center">
                            <button className="text-sm text-purple-600 hover:text-purple-700">
                              View all {campaign.content.length} content pieces
                            </button>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
};

export default Campaigns; 