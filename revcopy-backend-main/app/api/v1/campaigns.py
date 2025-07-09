"""
Campaigns API endpoints for campaign management.
"""

from typing import Dict, List, Optional
import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_async_session
from app.models.campaign import Campaign
from app.models.content import Content
from app.schemas.campaign import CampaignCreate, CampaignUpdate, CampaignResponse

# Configure logging
logger = structlog.get_logger(__name__)

# Create router
router = APIRouter()


@router.post("/", response_model=CampaignResponse)
async def create_campaign(
    campaign_data: CampaignCreate,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Create a new campaign.
    """
    try:
        logger.info("Creating campaign", name=campaign_data.name)
        
        # Create campaign
        campaign = Campaign(
            name=campaign_data.name,
            description=campaign_data.description,
            is_active=True,
            user_id=1  # TODO: Get from authenticated user
        )
        
        db.add(campaign)
        await db.commit()
        await db.refresh(campaign)
        
        logger.info("Campaign created successfully", campaign_id=campaign.id)
        
        return CampaignResponse(
            id=campaign.id,
            name=campaign.name,
            description=campaign.description,
            is_active=campaign.is_active,
            created_at=campaign.created_at,
            updated_at=campaign.updated_at,
            content=[]
        )
        
    except Exception as e:
        logger.error("Failed to create campaign", error=str(e))
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create campaign: {str(e)}"
        )


@router.get("/", response_model=List[CampaignResponse])
async def get_campaigns(
    db: AsyncSession = Depends(get_async_session)
):
    """
    Get all campaigns.
    """
    try:
        query = select(Campaign).order_by(Campaign.created_at.desc())
        result = await db.execute(query)
        campaigns = result.scalars().all()
        
        campaign_responses = []
        for campaign in campaigns:
            # Get content for this campaign
            content_query = select(Content).where(Content.campaign_id == campaign.id)
            content_result = await db.execute(content_query)
            content_list = content_result.scalars().all()
            
            campaign_responses.append(CampaignResponse(
                id=campaign.id,
                name=campaign.name,
                description=campaign.description,
                is_active=campaign.is_active,
                created_at=campaign.created_at,
                updated_at=campaign.updated_at,
                content=[
                    {
                        "id": content.id,
                        "content_type": content.content_type,
                        "title": content.title,
                        "content": content.content,
                        "word_count": content.word_count,
                        "character_count": content.character_count,
                        "language": content.language,
                        "created_at": content.created_at.isoformat(),
                        "status": content.status
                    }
                    for content in content_list
                ]
            ))
        
        return campaign_responses
        
    except Exception as e:
        logger.error("Failed to get campaigns", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get campaigns: {str(e)}"
        )


@router.get("/{campaign_id}", response_model=CampaignResponse)
async def get_campaign(
    campaign_id: int,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Get a specific campaign by ID.
    """
    try:
        query = select(Campaign).where(Campaign.id == campaign_id)
        result = await db.execute(query)
        campaign = result.scalar_one_or_none()
        
        if not campaign:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Campaign with ID {campaign_id} not found"
            )
        
        # Get content for this campaign
        content_query = select(Content).where(Content.campaign_id == campaign.id)
        content_result = await db.execute(content_query)
        content_list = content_result.scalars().all()
        
        return CampaignResponse(
            id=campaign.id,
            name=campaign.name,
            description=campaign.description,
            is_active=campaign.is_active,
            created_at=campaign.created_at,
            updated_at=campaign.updated_at,
            content=[
                {
                    "id": content.id,
                    "content_type": content.content_type,
                    "title": content.title,
                    "content": content.content,
                    "word_count": content.word_count,
                    "character_count": content.character_count,
                    "language": content.language,
                    "created_at": content.created_at.isoformat(),
                    "status": content.status
                }
                for content in content_list
            ]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to get campaign", campaign_id=campaign_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get campaign: {str(e)}"
        )


@router.put("/{campaign_id}", response_model=CampaignResponse)
async def update_campaign(
    campaign_id: int,
    campaign_data: CampaignUpdate,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Update a campaign.
    """
    try:
        query = select(Campaign).where(Campaign.id == campaign_id)
        result = await db.execute(query)
        campaign = result.scalar_one_or_none()
        
        if not campaign:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Campaign with ID {campaign_id} not found"
            )
        
        # Update campaign fields
        if campaign_data.name is not None:
            campaign.name = campaign_data.name
        if campaign_data.description is not None:
            campaign.description = campaign_data.description
        if campaign_data.is_active is not None:
            campaign.is_active = campaign_data.is_active
        
        await db.commit()
        await db.refresh(campaign)
        
        logger.info("Campaign updated successfully", campaign_id=campaign.id)
        
        # Get content for this campaign
        content_query = select(Content).where(Content.campaign_id == campaign.id)
        content_result = await db.execute(content_query)
        content_list = content_result.scalars().all()
        
        return CampaignResponse(
            id=campaign.id,
            name=campaign.name,
            description=campaign.description,
            is_active=campaign.is_active,
            created_at=campaign.created_at,
            updated_at=campaign.updated_at,
            content=[
                {
                    "id": content.id,
                    "content_type": content.content_type,
                    "title": content.title,
                    "content": content.content,
                    "word_count": content.word_count,
                    "character_count": content.character_count,
                    "language": content.language,
                    "created_at": content.created_at.isoformat(),
                    "status": content.status
                }
                for content in content_list
            ]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to update campaign", campaign_id=campaign_id, error=str(e))
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update campaign: {str(e)}"
        )


@router.delete("/{campaign_id}")
async def delete_campaign(
    campaign_id: int,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Delete a campaign and all its content.
    """
    try:
        query = select(Campaign).where(Campaign.id == campaign_id)
        result = await db.execute(query)
        campaign = result.scalar_one_or_none()
        
        if not campaign:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Campaign with ID {campaign_id} not found"
            )
        
        # Delete associated content first
        content_query = select(Content).where(Content.campaign_id == campaign.id)
        content_result = await db.execute(content_query)
        content_list = content_result.scalars().all()
        
        for content in content_list:
            await db.delete(content)
        
        # Delete campaign
        await db.delete(campaign)
        await db.commit()
        
        logger.info("Campaign deleted successfully", campaign_id=campaign_id)
        
        return {"message": "Campaign deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to delete campaign", campaign_id=campaign_id, error=str(e))
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete campaign: {str(e)}"
        )


@router.post("/{campaign_id}/content")
async def add_content_to_campaign(
    campaign_id: int,
    content_data: Dict,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Add content to a campaign.
    """
    try:
        # Check if campaign exists
        campaign_query = select(Campaign).where(Campaign.id == campaign_id)
        campaign_result = await db.execute(campaign_query)
        campaign = campaign_result.scalar_one_or_none()
        
        if not campaign:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Campaign with ID {campaign_id} not found"
            )
        
        # Create content
        content = Content(
            campaign_id=campaign_id,
            content_type=content_data.get("content_type", "general"),
            title=content_data.get("title", ""),
            content=content_data.get("content", ""),
            word_count=content_data.get("word_count", 0),
            character_count=content_data.get("character_count", 0),
            language=content_data.get("language", "en"),
            status=content_data.get("status", "draft"),
            parameters=content_data.get("parameters", {})
        )
        
        db.add(content)
        await db.commit()
        await db.refresh(content)
        
        logger.info("Content added to campaign", campaign_id=campaign_id, content_id=content.id)
        
        return {
            "id": content.id,
            "campaign_id": content.campaign_id,
            "content_type": content.content_type,
            "title": content.title,
            "content": content.content,
            "word_count": content.word_count,
            "character_count": content.character_count,
            "language": content.language,
            "status": content.status,
            "created_at": content.created_at.isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to add content to campaign", campaign_id=campaign_id, error=str(e))
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add content to campaign: {str(e)}"
        ) 