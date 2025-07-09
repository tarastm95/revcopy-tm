/**
 * Prompts Management Component for RevCopy Admin Panel
 * 
 * Provides comprehensive prompt template management with:
 * - Real-time data from backend API
 * - CRUD operations (Create, Read, Update, Delete)
 * - Form validation and error handling
 * - Loading states and user feedback
 * - Template variables with clickable insertion
 * - Responsive design
 */

import React, { useState, useRef, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Edit, Trash2, Save, X, AlertCircle, Loader2, Copy, Hash, Search } from 'lucide-react';
import { useForm, UseFormRegister, FieldError } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { apiClient } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';

/**
 * Prompt template validation schema
 */
const promptSchema = z.object({
  content: z.string().min(1, 'Content is required').min(10, 'Content must be at least 10 characters'),
  category: z.string().min(1, 'Category is required'),
  isActive: z.boolean().default(true),
});

type PromptFormData = z.infer<typeof promptSchema>;

interface PromptTemplate {
  id: number;
  content: string;
  category: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

/**
 * Essential template variables - simplified
 */
const TEMPLATE_VARIABLES = {
  'Essential Variables': [
    { variable: '{product_description}', description: 'Product description' },
    { variable: '{positive_reviews}', description: 'Positive customer reviews' },
    { variable: '{negative_reviews}', description: 'Negative customer reviews' },
    { variable: '{product_name}', description: 'Product name/title' },
    { variable: '{brand}', description: 'Brand name' },
    { variable: '{price}', description: 'Product price' },
  ],
};

/**
 * Content-specific prompt categories - each is its own complete entity
 * These MUST match the exact backend categories that the frontend requests!
 */
const PROMPT_CATEGORIES = [
  // Core categories that frontend actually requests (PRIORITY)
  { value: 'facebook_ad', label: '📘 Facebook Ad', priority: true },
  { value: 'product_description', label: '📦 Product Description', priority: true },
  { value: 'google_ad', label: '🔍 Google Ad', priority: true },
  { value: 'instagram_caption', label: '📸 Instagram Caption', priority: true },
  { value: 'blog_article', label: '📝 Blog Article', priority: true },
  { value: 'product_comparison', label: '⚖️ Product Comparison', priority: true },
  { value: 'faq', label: '❓ FAQ', priority: true },
  { value: 'email_campaign', label: '📧 Email Campaign', priority: true },
  
  // Additional categories for extended functionality
  { value: 'instagram_post', label: 'Instagram Post' },
  { value: 'linkedin_post', label: 'LinkedIn Post' },
  { value: 'twitter_post', label: 'Twitter Post' },
  { value: 'instagram_story', label: 'Instagram Story' },
  { value: 'google_search_ad', label: 'Google Search Ad' },
  { value: 'google_display_ad', label: 'Google Display Ad' },
  { value: 'google_shopping_ad', label: 'Google Shopping Ad' },
  { value: 'product_title', label: 'Product Title' },
  { value: 'product_features', label: 'Product Features' },
  { value: 'product_benefits', label: 'Product Benefits' },
  { value: 'email_subject', label: 'Email Subject Line' },
  { value: 'newsletter', label: 'Newsletter' },
  { value: 'welcome_email', label: 'Welcome Email' },
  { value: 'landing_page', label: 'Landing Page' },
  { value: 'homepage_hero', label: 'Homepage Hero' },
  { value: 'about_us', label: 'About Us Page' },
  { value: 'blog_post', label: 'Blog Post' },
  { value: 'sales_copy', label: 'Sales Copy' },
  { value: 'press_release', label: 'Press Release' },
  { value: 'case_study', label: 'Case Study' },
  { value: 'testimonial', label: 'Customer Testimonial' },
  { value: 'category_description', label: 'Category Description' },
  { value: 'brand_story', label: 'Brand Story' },
  { value: 'shipping_policy', label: 'Shipping Policy' },
  { value: 'return_policy', label: 'Return Policy' },
  { value: 'faq_answer', label: 'FAQ Answer' },
  { value: 'help_article', label: 'Help Article' },
  { value: 'chatbot_response', label: 'Chatbot Response' },
  { value: 'youtube_description', label: 'YouTube Description' },
  { value: 'video_script', label: 'Video Script' },
  { value: 'podcast_description', label: 'Podcast Description' },
];

/**
 * Template Variables Component
 */
interface TemplateVariablesProps {
  onVariableClick: (variable: string) => void;
}

const TemplateVariables: React.FC<TemplateVariablesProps> = ({ onVariableClick }) => {
  const [expandedCategory, setExpandedCategory] = useState<string | null>('Essential Variables');
  const { toast } = useToast();

  const handleVariableClick = (variable: string) => {
    onVariableClick(variable);
    navigator.clipboard.writeText(variable);
    toast({
      title: 'Variable Copied',
      description: `${variable} has been copied to clipboard and inserted`,
    });
  };

  return (
    <div className="bg-gray-50 rounded-lg border border-gray-200 p-4 mb-4">
      <div className="flex items-center mb-3">
        <Hash className="w-4 h-4 mr-2 text-indigo-600" />
        <h4 className="text-sm font-semibold text-gray-900">Template Variables</h4>
        <span className="text-xs text-gray-500 ml-2">(Click to insert)</span>
      </div>
      
      <div className="space-y-3">
        {Object.entries(TEMPLATE_VARIABLES).map(([category, variables]) => (
          <div key={category} className="border border-gray-200 rounded-lg overflow-hidden">
            <button
              onClick={() => setExpandedCategory(expandedCategory === category ? null : category)}
              className="w-full px-3 py-2 bg-white hover:bg-gray-50 text-left text-sm font-medium text-gray-700 border-b border-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-inset"
            >
              <div className="flex items-center justify-between">
                <span>{category}</span>
                <span className="text-xs text-gray-500">
                  {expandedCategory === category ? '▼' : '▶'}
                </span>
              </div>
            </button>
            
            {expandedCategory === category && (
              <div className="bg-white p-3 space-y-2">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                  {variables.map(({ variable, description }) => (
                    <button
                      key={variable}
                      onClick={() => handleVariableClick(variable)}
                      className="group flex items-center justify-between p-2 text-left bg-gray-50 hover:bg-indigo-50 border border-gray-200 hover:border-indigo-300 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    >
                      <div className="flex-1 min-w-0">
                        <code className="text-xs font-mono text-indigo-600 group-hover:text-indigo-700 block">
                          {variable}
                        </code>
                        <p className="text-xs text-gray-600 mt-1">{description}</p>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

/**
 * Main Prompts Management Component
 */
const PromptsManagement: React.FC = () => {
  const [showAddForm, setShowAddForm] = useState(false);
  const [editingPrompt, setEditingPrompt] = useState<number | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const queryClient = useQueryClient();
  const { toast } = useToast();

  // Fetch prompts
  const { data: prompts = [], isLoading, error, refetch } = useQuery({
    queryKey: ['prompts'],
    queryFn: async () => {
      try {
        const response = await apiClient.get('/api/v1/prompts/');
        return response.data || [];
      } catch (error) {
        console.error('Failed to fetch prompts:', error);
        return [];
      }
    },
  });

  // Create prompt mutation
  const createPromptMutation = useMutation({
    mutationFn: async (data: PromptFormData) => {
      const response = await apiClient.post('/api/v1/prompts/', {
        content: data.content,
        category: data.category,
        is_active: data.isActive,
      });
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['prompts'] });
      toast({
        title: 'Success',
        description: 'Prompt template created successfully',
      });
      setShowAddForm(false);
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error.response?.data?.detail || 'Failed to create prompt template',
        variant: 'destructive',
      });
    },
  });

  // Update prompt mutation
  const updatePromptMutation = useMutation({
    mutationFn: async ({ id, data }: { id: number; data: PromptFormData }) => {
      const response = await apiClient.put(`/api/v1/prompts/${id}`, {
        content: data.content,
        category: data.category,
        is_active: data.isActive,
      });
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['prompts'] });
      toast({
        title: 'Success',
        description: 'Prompt template updated successfully',
      });
      setEditingPrompt(null);
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error.response?.data?.detail || 'Failed to update prompt template',
        variant: 'destructive',
      });
    },
  });

  // Delete prompt mutation
  const deletePromptMutation = useMutation({
    mutationFn: async (id: number) => {
      await apiClient.delete(`/api/v1/prompts/${id}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['prompts'] });
      toast({
        title: 'Success',
        description: 'Prompt template deleted successfully',
      });
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error.response?.data?.detail || 'Failed to delete prompt template',
        variant: 'destructive',
      });
    },
  });

  const handleDelete = async (id: number): Promise<void> => {
    if (confirm('Are you sure you want to delete this prompt template?')) {
      deletePromptMutation.mutate(id);
    }
  };

  const handleRetry = (): void => {
    refetch();
  };

  const filteredPrompts = prompts.filter((prompt: PromptTemplate) => {
    const matchesSearch = prompt.content.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         prompt.category.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = selectedCategory === 'all' || prompt.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  if (isLoading) {
    return (
      <div className="p-8">
        <div className="flex items-center justify-center h-64">
          <Loader2 className="w-8 h-8 animate-spin text-indigo-600" />
          <span className="ml-2 text-gray-600">Loading prompt templates...</span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <AlertCircle className="w-8 h-8 text-red-500 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-red-900 mb-2">Failed to load prompt templates</h3>
          <p className="text-red-700 mb-4">There was an error loading the prompt templates.</p>
          <Button onClick={handleRetry} variant="outline">
            Try Again
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Prompt Templates</h1>
        <p className="text-gray-600 mt-2">Manage AI prompt templates for content generation</p>
      </div>

      {/* Controls */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center space-x-4">
          <div className="relative">
            <input
              type="text"
              placeholder="Search prompts..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            />
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
          </div>
          <select
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          >
            <option value="all">All Categories</option>
            {PROMPT_CATEGORIES.map((category) => (
              <option key={category.value} value={category.value}>
                {category.label}
              </option>
            ))}
          </select>
        </div>
        <Button onClick={() => setShowAddForm(true)}>
          <Plus className="w-4 h-4 mr-2" />
          Add Template
        </Button>
      </div>

      {/* Add/Edit Form */}
      {(showAddForm || editingPrompt !== null) && (
        <AddPromptForm
          onSubmit={(data) => {
            if (editingPrompt) {
              updatePromptMutation.mutate({ id: editingPrompt, data });
            } else {
              createPromptMutation.mutate(data);
            }
          }}
          onCancel={() => {
            setShowAddForm(false);
            setEditingPrompt(null);
          }}
          isLoading={createPromptMutation.isPending || updatePromptMutation.isPending}
          categories={PROMPT_CATEGORIES}
        />
      )}

      {/* Prompts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {filteredPrompts.map((prompt: PromptTemplate) => (
          <PromptCard
            key={prompt.id}
            prompt={prompt}
            isEditing={editingPrompt === prompt.id}
            onEdit={() => setEditingPrompt(prompt.id)}
            onSave={(data) => updatePromptMutation.mutate({ id: prompt.id, data })}
            onDelete={() => handleDelete(prompt.id)}
            onCancel={() => setEditingPrompt(null)}
            isLoading={updatePromptMutation.isPending}
            categories={PROMPT_CATEGORIES}
          />
        ))}
      </div>

      {filteredPrompts.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500">No prompt templates found.</p>
        </div>
      )}
    </div>
  );
};

/**
 * Add Prompt Form Component
 */
interface AddPromptFormProps {
  onSubmit: (data: PromptFormData) => void;
  onCancel: () => void;
  isLoading: boolean;
  categories: Array<{ value: string; label: string }>;
}

const AddPromptForm: React.FC<AddPromptFormProps> = ({ onSubmit, onCancel, isLoading, categories }) => {
  const [content, setContent] = useState('');
  const [category, setCategory] = useState('');
  const [isActive, setIsActive] = useState(true);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleFormSubmit = (data: PromptFormData): void => {
    onSubmit(data);
  };

  const handleVariableInsert = (variable: string): void => {
    if (textareaRef.current) {
      const start = textareaRef.current.selectionStart;
      const end = textareaRef.current.selectionEnd;
      const newContent = content.substring(0, start) + variable + content.substring(end);
      setContent(newContent);
      
      // Set cursor position after the inserted variable
      setTimeout(() => {
        if (textareaRef.current) {
          textareaRef.current.focus();
          textareaRef.current.setSelectionRange(start + variable.length, start + variable.length);
        }
      }, 0);
    }
  };

  const handleUseTemplate = (): void => {
    // Set a default template based on selected category
    const template = getDefaultTemplate(category);
    if (template) {
      setContent(template);
    }
  };

  const getDefaultTemplate = (selectedCategory: string): string => {
    const templates: Record<string, string> = {
      'facebook_ad': 'Create a compelling Facebook ad for {product_name} that highlights {positive_reviews} and addresses {negative_reviews}. Keep it under 125 characters with a clear call-to-action.',
      'product_description': 'Write a detailed product description for {product_name} based on {product_description}. Highlight benefits from {positive_reviews} and address concerns from {negative_reviews}. Include key features and specifications.',
      'google_ad': 'Create a Google ad with compelling headline (30 chars max) and description (90 chars max) for {product_name}. Highlight {positive_reviews} and include {price}. Focus on key benefits and include a strong CTA.',
      'instagram_caption': 'Write an engaging Instagram caption for {product_name} featuring {positive_reviews}. Use emojis, 3-5 relevant hashtags, and mention {price} if competitive. Keep it conversational and visual.',
      'blog_article': 'Write a comprehensive blog article about {product_name} based on {product_description}. Feature customer insights from {positive_reviews}, address concerns from {negative_reviews}, and provide detailed analysis.',
      'email_campaign': 'Create an email campaign for {product_name} featuring social proof from {positive_reviews}. Address common objections from {negative_reviews}, include {price} and compelling call-to-action. Make it personal and engaging.',
    };
    return templates[selectedCategory] || '';
  };

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6 mb-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold text-gray-900">Add Prompt Template</h3>
        <button onClick={onCancel} className="text-gray-400 hover:text-gray-600">
          <X className="w-5 h-5" />
        </button>
      </div>

      <form onSubmit={(e) => {
        e.preventDefault();
        if (content.trim() && category) {
          handleFormSubmit({ content: content.trim(), category, isActive });
        }
      }}>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Category *
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              required
            >
              <option value="">Select a category</option>
              {categories.map((cat) => (
                <option key={cat.value} value={cat.value}>
                  {cat.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Prompt Content *
            </label>
            <textarea
              ref={textareaRef}
              value={content}
              onChange={(e) => setContent(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              rows={8}
              placeholder="Enter your prompt template here..."
              required
            />
          </div>

          <div className="flex items-center">
            <input
              type="checkbox"
              id="isActive"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
            />
            <label htmlFor="isActive" className="ml-2 block text-sm text-gray-900">
              Active
            </label>
          </div>

          <TemplateVariables onVariableClick={handleVariableInsert} />

          {category && (
            <div className="flex items-center space-x-2">
              <Button
                type="button"
                variant="outline"
                onClick={handleUseTemplate}
                className="text-sm"
              >
                Use Default Template
              </Button>
            </div>
          )}

          <div className="flex items-center space-x-3">
            <Button
              type="submit"
              disabled={isLoading || !content.trim() || !category}
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Saving...
                </>
              ) : (
                <>
                  <Save className="w-4 h-4 mr-2" />
                  Save Template
                </>
              )}
            </Button>
            <Button type="button" variant="outline" onClick={onCancel}>
              Cancel
            </Button>
          </div>
        </div>
      </form>
    </div>
  );
};

/**
 * Prompt Card Component
 */
interface PromptCardProps {
  prompt: PromptTemplate;
  isEditing: boolean;
  onEdit: () => void;
  onSave: (data: PromptFormData) => void;
  onDelete: () => void;
  onCancel: () => void;
  isLoading: boolean;
  categories: Array<{ value: string; label: string }>;
}

const PromptCard: React.FC<PromptCardProps> = ({ 
  prompt, 
  isEditing, 
  onEdit, 
  onSave, 
  onDelete, 
  onCancel, 
  isLoading,
  categories 
}) => {
  const [content, setContent] = useState(prompt.content);
  const [category, setCategory] = useState(prompt.category);
  const [isActive, setIsActive] = useState(prompt.is_active);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const getCategoryLabel = (value: string): string => {
    const category = categories.find(cat => cat.value === value);
    return category ? category.label : value;
  };

  const handleEditVariableInsert = (variable: string): void => {
    if (textareaRef.current) {
      const start = textareaRef.current.selectionStart;
      const end = textareaRef.current.selectionEnd;
      const newContent = content.substring(0, start) + variable + content.substring(end);
      setContent(newContent);
      
      setTimeout(() => {
        if (textareaRef.current) {
          textareaRef.current.focus();
          textareaRef.current.setSelectionRange(start + variable.length, start + variable.length);
        }
      }, 0);
    }
  };

  const handleEditUseTemplate = (): void => {
    const template = getDefaultTemplate(category);
    if (template) {
      setContent(template);
    }
  };

  const getDefaultTemplate = (selectedCategory: string): string => {
    const templates: Record<string, string> = {
      'facebook_ad': 'Create a compelling Facebook ad for {product_name} that highlights {positive_reviews} and addresses {negative_reviews}. Keep it under 125 characters with a clear call-to-action.',
      'product_description': 'Write a detailed product description for {product_name} based on {product_description}. Highlight benefits from {positive_reviews} and address concerns from {negative_reviews}. Include key features and specifications.',
      'google_ad': 'Create a Google ad with compelling headline (30 chars max) and description (90 chars max) for {product_name}. Highlight {positive_reviews} and include {price}. Focus on key benefits and include a strong CTA.',
      'instagram_caption': 'Write an engaging Instagram caption for {product_name} featuring {positive_reviews}. Use emojis, 3-5 relevant hashtags, and mention {price} if competitive. Keep it conversational and visual.',
      'blog_article': 'Write a comprehensive blog article about {product_name} based on {product_description}. Feature customer insights from {positive_reviews}, address concerns from {negative_reviews}, and provide detailed analysis.',
      'email_campaign': 'Create an email campaign for {product_name} featuring social proof from {positive_reviews}. Address common objections from {negative_reviews}, include {price} and compelling call-to-action. Make it personal and engaging.',
    };
    return templates[selectedCategory] || '';
  };

  if (isEditing) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Edit Template</h3>
          <button onClick={onCancel} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={(e) => {
          e.preventDefault();
          if (content.trim() && category) {
            onSave({ content: content.trim(), category, isActive });
          }
        }}>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Category *
              </label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                required
              >
                {categories.map((cat) => (
                  <option key={cat.value} value={cat.value}>
                    {cat.label}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Prompt Content *
              </label>
              <textarea
                ref={textareaRef}
                value={content}
                onChange={(e) => setContent(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                rows={6}
                required
              />
            </div>

            <div className="flex items-center">
              <input
                type="checkbox"
                id={`isActive-${prompt.id}`}
                checked={isActive}
                onChange={(e) => setIsActive(e.target.checked)}
                className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
              />
              <label htmlFor={`isActive-${prompt.id}`} className="ml-2 block text-sm text-gray-900">
                Active
              </label>
            </div>

            <TemplateVariables onVariableClick={handleEditVariableInsert} />

            <div className="flex items-center space-x-3">
              <Button
                type="submit"
                disabled={isLoading || !content.trim() || !category}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Saving...
                  </>
                ) : (
                  <>
                    <Save className="w-4 h-4 mr-2" />
                    Save Changes
                  </>
                )}
              </Button>
              <Button type="button" variant="outline" onClick={onCancel}>
                Cancel
              </Button>
            </div>
          </div>
        </form>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6">
      <div className="flex items-start justify-between mb-4">
        <div className="flex-1">
          <div className="flex items-center space-x-2 mb-2">
            <span className="px-2 py-1 bg-indigo-100 text-indigo-800 rounded text-xs font-medium">
              {getCategoryLabel(prompt.category)}
            </span>
            <span className={`px-2 py-1 rounded text-xs font-medium ${
              prompt.is_active 
                ? 'bg-green-100 text-green-800' 
                : 'bg-gray-100 text-gray-800'
            }`}>
              {prompt.is_active ? 'Active' : 'Inactive'}
            </span>
          </div>
          <p className="text-sm text-gray-600 line-clamp-3">{prompt.content}</p>
        </div>
        <div className="flex items-center space-x-2">
          <button
            onClick={onEdit}
            className="text-gray-400 hover:text-gray-600 p-1"
            title="Edit template"
          >
            <Edit className="w-4 h-4" />
          </button>
          <button
            onClick={onDelete}
            className="text-red-400 hover:text-red-600 p-1"
            title="Delete template"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>
      
      <div className="flex items-center justify-between text-xs text-gray-500">
        <span>Updated {new Date(prompt.updated_at).toLocaleDateString()}</span>
        <button
          onClick={() => navigator.clipboard.writeText(prompt.content)}
          className="text-gray-400 hover:text-gray-600"
          title="Copy template"
        >
          <Copy className="w-3 h-3" />
        </button>
      </div>
    </div>
  );
};

export default PromptsManagement;
