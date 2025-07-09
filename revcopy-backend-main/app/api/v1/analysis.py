"""
Analysis API endpoints for product review analysis.
"""

from typing import Dict, Optional
import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_async_session
from app.models.analysis import Analysis
from app.services.analysis import AnalysisService

# Configure logging
logger = structlog.get_logger(__name__)

# Create router
router = APIRouter()


@router.get("/{analysis_id}", response_model=Dict)
async def get_analysis_status(
    analysis_id: int,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Get analysis status and basic information.
    """
    try:
        query = select(Analysis).where(Analysis.id == analysis_id)
        result = await db.execute(query)
        analysis = result.scalar_one_or_none()
        
        if not analysis:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Analysis with ID {analysis_id} not found"
            )
        
        return {
            "analysis_id": analysis.id,
            "status": analysis.status.value,
            "analysis_type": analysis.analysis_type,
            "total_reviews_processed": analysis.total_reviews_processed,
            "created_at": analysis.created_at.isoformat() if analysis.created_at else None,
            "started_at": analysis.started_at.isoformat() if analysis.started_at else None,
            "completed_at": analysis.completed_at.isoformat() if analysis.completed_at else None,
            "error_message": analysis.error_message
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to get analysis status", analysis_id=analysis_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get analysis status: {str(e)}"
        )


@router.get("/{analysis_id}/results", response_model=Dict)
async def get_analysis_results(
    analysis_id: int,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Get detailed analysis results.
    """
    try:
        analysis_service = AnalysisService()
        results = await analysis_service.get_analysis_results(analysis_id, db)
        
        if not results:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Analysis results not found for ID {analysis_id}"
            )
        
        return results
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to get analysis results", analysis_id=analysis_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get analysis results: {str(e)}"
        )


@router.post("/{analysis_id}/retry")
async def retry_analysis(
    analysis_id: int,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Retry a failed analysis.
    """
    try:
        query = select(Analysis).where(Analysis.id == analysis_id)
        result = await db.execute(query)
        analysis = result.scalar_one_or_none()
        
        if not analysis:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Analysis with ID {analysis_id} not found"
            )
        
        if analysis.status.value not in ["failed", "cancelled"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only failed or cancelled analyses can be retried"
            )
        
        # Reset analysis status
        analysis.status = "pending"
        analysis.error_message = None
        analysis.started_at = None
        analysis.completed_at = None
        
        await db.commit()
        
        # Process analysis
        analysis_service = AnalysisService()
        success = await analysis_service.process_analysis(analysis, db)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to retry analysis"
            )
        
        return {
            "analysis_id": analysis.id,
            "status": "retried",
            "message": "Analysis retry completed successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to retry analysis", analysis_id=analysis_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retry analysis: {str(e)}"
        )


@router.delete("/{analysis_id}")
async def delete_analysis(
    analysis_id: int,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Delete an analysis and its results.
    """
    try:
        query = select(Analysis).where(Analysis.id == analysis_id)
        result = await db.execute(query)
        analysis = result.scalar_one_or_none()
        
        if not analysis:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Analysis with ID {analysis_id} not found"
            )
        
        await db.delete(analysis)
        await db.commit()
        
        return {
            "analysis_id": analysis_id,
            "message": "Analysis deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to delete analysis", analysis_id=analysis_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete analysis: {str(e)}"
        ) 