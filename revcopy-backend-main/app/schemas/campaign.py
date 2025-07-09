"""
Campaign schemas for API validation and serialization.
"""

from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel, Field


class CampaignCreate(BaseModel):
    """Schema for creating a new campaign."""
    name: str = Field(..., min_length=1, max_length=255, description="Campaign name")
    description: Optional[str] = Field(None, max_length=1000, description="Campaign description")


class CampaignUpdate(BaseModel):
    """Schema for updating a campaign."""
    name: Optional[str] = Field(None, min_length=1, max_length=255, description="Campaign name")
    description: Optional[str] = Field(None, max_length=1000, description="Campaign description")
    is_active: Optional[bool] = Field(None, description="Whether the campaign is active")


class CampaignContent(BaseModel):
    """Schema for campaign content."""
    id: int
    content_type: str
    title: str
    content: str
    word_count: int
    character_count: int
    language: str
    created_at: str
    status: str


class CampaignResponse(BaseModel):
    """Schema for campaign response."""
    id: int
    name: str
    description: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime
    content: List[CampaignContent] = []


class CampaignListResponse(BaseModel):
    """Schema for campaign list response."""
    campaigns: List[CampaignResponse]
    total: int
    page: int
    page_size: int
    total_pages: int 