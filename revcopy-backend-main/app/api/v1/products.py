"""
Product analysis and management API endpoints.
"""

from typing import Dict, Optional
import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_async_session
from app.models.product import Product
from app.models.user import User
from app.services.product import ProductService
from app.services.analysis import AnalysisService
from app.schemas.product import ProductAnalysisRequest, ProductAnalysisResponse

# Configure logging
logger = structlog.get_logger(__name__)

# Create router
router = APIRouter()


@router.post("/analyze", response_model=ProductAnalysisResponse)
async def analyze_product(
    request: ProductAnalysisRequest,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Analyze a product URL and extract product data with reviews.
    """
    try:
        logger.info("Starting product analysis", url=str(request.url))
        
        # Get or create user (for now, use a default user)
        # TODO: Implement proper authentication
        user_id = 1  # Default user ID
        
        # Initialize services
        product_service = ProductService()
        analysis_service = AnalysisService()
        
        # Validate and extract product data
        is_valid, product_data, error_message = await product_service.validate_and_extract_product(
            str(request.url), 
            user_id,
            db
        )
        
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error_message or "Invalid product URL"
            )
        
        # Create analysis record
        analysis = await analysis_service.create_analysis(
            product_id=product_data.get("id"),
            user_id=user_id,
            analysis_type=request.analysis_type,
            max_reviews=request.max_reviews,
            db=db
        )
        
        # Process analysis in background
        # For now, process immediately
        success = await analysis_service.process_analysis(analysis, db)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to process analysis"
            )
        
        # Get analysis results
        analysis_results = await analysis_service.get_analysis_results(analysis.id, db)
        
        if not analysis_results:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to retrieve analysis results"
            )
        
        logger.info("Product analysis completed successfully", 
                   analysis_id=analysis.id,
                   product_id=product_data.get("id"))
        
        return ProductAnalysisResponse(
            success=True,
            data={
                "analysis_id": analysis.id,
                "product": product_data,
                "analysis": analysis_results
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Product analysis failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )


@router.get("/{product_id}", response_model=Dict)
async def get_product(
    product_id: int,
    db: AsyncSession = Depends(get_async_session)
):
    """
    Get product details by ID.
    """
    try:
        query = select(Product).where(Product.id == product_id)
        result = await db.execute(query)
        product = result.scalar_one_or_none()
        
        if not product:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Product with ID {product_id} not found"
            )
        
        return {
            "id": product.id,
            "title": product.title,
            "description": product.description,
            "brand": product.brand,
            "category": product.category,
            "price": product.price,
            "currency": product.currency,
            "rating": product.rating,
            "review_count": product.review_count,
            "platform": product.platform.value,
            "url": product.url,
            "created_at": product.created_at.isoformat() if product.created_at else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to get product", product_id=product_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get product: {str(e)}"
        )


@router.get("/", response_model=Dict)
async def list_products(
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_async_session)
):
    """
    List products with pagination.
    """
    try:
        query = select(Product).order_by(Product.created_at.desc()).offset(offset).limit(limit)
        result = await db.execute(query)
        products = result.scalars().all()
        
        return {
            "products": [
                {
                    "id": product.id,
                    "title": product.title,
                    "brand": product.brand,
                    "price": product.price,
                    "currency": product.currency,
                    "rating": product.rating,
                    "platform": product.platform.value,
                    "created_at": product.created_at.isoformat() if product.created_at else None
                }
                for product in products
            ],
            "total": len(products),
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        logger.error("Failed to list products", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list products: {str(e)}"
        ) 