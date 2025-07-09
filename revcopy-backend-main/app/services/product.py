"""
Product service for managing products and e-commerce platform integration.
"""

import structlog
from typing import Dict, List, Optional, Tuple
from datetime import datetime
from urllib.parse import urlparse

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.product import Product, EcommercePlatform
from app.services.amazon_crawler_client import AmazonCrawlerClient
from app.services.review_scraping import ReviewScrapingService

# Configure logging
logger = structlog.get_logger(__name__)


class ProductService:
    """Service for product data extraction and analysis."""
    
    def __init__(self):
        self.amazon_crawler = AmazonCrawlerClient()
        self.review_service = ReviewScrapingService()
    
    async def validate_and_extract_product(
        self, 
        url: str, 
        user_id: int,
        db: AsyncSession
    ) -> Tuple[bool, Optional[Dict], Optional[str]]:
        """
        Validate product URL and extract product data.
        
        Returns:
            Tuple[bool, Optional[Dict], Optional[str]]: (is_valid, product_data, error_message)
        """
        try:
            logger.info("Starting product validation and extraction", url=url)
            
            # Basic URL validation
            if not url or not url.strip():
                return False, None, "Product URL is required"
            
            try:
                parsed_url = urlparse(url.strip())
                if not parsed_url.scheme or not parsed_url.netloc:
                    return False, None, "Invalid URL format"
            except Exception:
                return False, None, "Invalid URL format"
            
            # Determine platform
            platform = self._detect_platform(url)
            if not platform:
                return False, None, "Unsupported e-commerce platform"
            
            # Extract product data based on platform
            product_data = None
            
            if platform == EcommercePlatform.AMAZON:
                product_data = await self._extract_amazon_product(url, user_id)
            elif platform == EcommercePlatform.SHOPIFY:
                product_data = await self._extract_shopify_product(url, user_id)
            else:
                return False, None, f"Platform {platform.value} is not yet supported"
            
            if not product_data:
                return False, None, "Failed to extract product data"
            
            # Save to database
            product = Product(
                url=url,
                platform=platform,
                external_product_id=product_data["external_product_id"],
                title=product_data["title"],
                description=product_data["description"],
                brand=product_data.get("brand"),
                category=product_data.get("category"),
                price=product_data.get("price"),
                currency=product_data.get("currency", "USD"),
                original_price=product_data.get("original_price"),
                rating=product_data.get("rating"),
                review_count=product_data.get("review_count", 0),
                in_stock=product_data.get("in_stock", True),
                tags=product_data.get("tags", []),
                crawl_metadata=product_data.get("crawl_metadata", {}),
                images_data=product_data.get("images_data", []),
                reviews_data=product_data.get("reviews_data", []),
                user_id=user_id
            )
            
            db.add(product)
            await db.commit()
            await db.refresh(product)
            
            logger.info("Product extracted and saved successfully", product_id=product.id)
            return True, product_data, None
            
        except Exception as e:
            logger.error("Product extraction failed", error=str(e), url=url)
            return False, None, f"Product extraction failed: {str(e)}"
    
    def _detect_platform(self, url: str) -> Optional[EcommercePlatform]:
        """Detect e-commerce platform from URL."""
        url_lower = url.lower()
        
        if "amazon.com" in url_lower or "amazon." in url_lower:
            return EcommercePlatform.AMAZON
        elif "shopify.com" in url_lower or ".myshopify.com" in url_lower:
            return EcommercePlatform.SHOPIFY
        elif "etsy.com" in url_lower:
            return EcommercePlatform.ETSY
        elif "ebay.com" in url_lower:
            return EcommercePlatform.EBAY
        elif "aliexpress.com" in url_lower:
            return EcommercePlatform.ALIEXPRESS
        else:
            return None
    
    async def _extract_amazon_product(self, url: str, user_id: int) -> Optional[Dict]:
        """Extract Amazon product data using crawler service."""
        try:
            logger.info("Extracting Amazon product data", url=url)
            
            # Try to get product data from Amazon crawler
            product_data = await self.amazon_crawler.get_product_data(url)
            
            if product_data:
                logger.info("Amazon product data extracted successfully", asin=product_data.get("asin"))
                return product_data
            
            # If crawler fails, return error
            logger.error("Amazon crawler service unavailable")
            return None
            
        except Exception as e:
            logger.error("Amazon extraction failed", error=str(e), url=url)
            return None
    
    async def _extract_shopify_product(self, url: str, user_id: int) -> Optional[Dict]:
        """Extract Shopify product data using crawler service."""
        try:
            logger.info("Extracting Shopify product data", url=url)
            
            # Extract handle from URL
            parsed_url = urlparse(url)
            path_parts = parsed_url.path.strip('/').split('/')
            
            if 'products' in path_parts:
                product_index = path_parts.index('products')
                if product_index + 1 < len(path_parts):
                    handle = path_parts[product_index + 1]
                else:
                    return None
            else:
                return None
            
            # Try to get product data from Shopify crawler
            # This would need to be implemented in the crawler service
            logger.info("Shopify crawler service not yet implemented")
            return None
            
        except Exception as e:
            logger.error("Shopify extraction failed", error=str(e), url=url)
            return None

