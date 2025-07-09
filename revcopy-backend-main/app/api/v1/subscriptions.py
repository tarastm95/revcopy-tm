"""
Subscription and Payment Plans API

This module handles:
- Available subscription plans and pricing
- User subscription management  
- Usage limit enforcement
- Payment processing integration
- Plan upgrades and downgrades
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from decimal import Decimal

import structlog
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_
from pydantic import BaseModel, Field

from app.api.deps import get_async_session, get_current_user
from app.models.user import User
from app.schemas.user import (
    SubscriptionPlan, 
    UserUsageLimits, 
    UsageLimitCheck,
    FREE_PLAN_LIMITS,
    BASIC_PLAN_LIMITS, 
    PRO_PLAN_LIMITS,
    ENTERPRISE_PLAN_LIMITS
)

logger = structlog.get_logger(__name__)
router = APIRouter()


# Pricing Configuration
SUBSCRIPTION_PLANS = {
    SubscriptionPlan.FREE: {
        "name": "Free Plan",
        "description": "Perfect for trying out RevCopy",
        "price": 0.00,
        "currency": "USD",
        "billing_period": "forever",
        "features": [
            "10 content generations per month",
            "3 generations per day",
            "2 campaigns maximum", 
            "5 products per campaign",
            "Basic templates",
            "Email support"
        ],
        "limits": FREE_PLAN_LIMITS,
        "popular": False,
        "trial_days": 0
    },
    SubscriptionPlan.BASIC: {
        "name": "Basic Plan", 
        "description": "Great for small businesses and freelancers",
        "price": 29.00,
        "currency": "USD",
        "billing_period": "monthly",
        "features": [
            "100 content generations per month",
            "10 generations per day",
            "10 campaigns maximum",
            "20 products per campaign", 
            "All content types",
            "Custom prompts",
            "Email support",
            "Analytics dashboard"
        ],
        "limits": BASIC_PLAN_LIMITS,
        "popular": False,
        "trial_days": 7
    },
    SubscriptionPlan.PRO: {
        "name": "Pro Plan",
        "description": "Perfect for growing businesses",
        "price": 99.00,
        "currency": "USD", 
        "billing_period": "monthly",
        "features": [
            "500 content generations per month",
            "50 generations per day",
            "50 campaigns maximum",
            "100 products per campaign",
            "All content types",
            "Custom prompts",
            "Priority support",
            "Advanced analytics",
            "A/B testing",
            "API access",
            "White-label options"
        ],
        "limits": PRO_PLAN_LIMITS,
        "popular": True,
        "trial_days": 14
    },
    SubscriptionPlan.ENTERPRISE: {
        "name": "Enterprise Plan",
        "description": "For large organizations with custom needs",
        "price": 499.00,
        "currency": "USD",
        "billing_period": "monthly", 
        "features": [
            "10,000 content generations per month",
            "500 generations per day",
            "Unlimited campaigns",
            "Unlimited products per campaign",
            "All content types",
            "Custom prompts & templates",
            "Dedicated account manager",
            "Advanced analytics & reporting",
            "Custom integrations",
            "Full API access",
            "White-label solution",
            "Custom model training",
            "SLA guarantee"
        ],
        "limits": ENTERPRISE_PLAN_LIMITS,
        "popular": False,
        "trial_days": 30
    }
}


class PlanResponse(BaseModel):
    """Subscription plan response schema."""
    plan_id: SubscriptionPlan = Field(..., description="Plan identifier")
    name: str = Field(..., description="Plan name")
    description: str = Field(..., description="Plan description")
    price: float = Field(..., description="Monthly price")
    currency: str = Field(..., description="Price currency")
    billing_period: str = Field(..., description="Billing period")
    features: List[str] = Field(..., description="Plan features list")
    limits: UserUsageLimits = Field(..., description="Usage limits")
    popular: bool = Field(..., description="Popular plan flag")
    trial_days: int = Field(..., description="Free trial days")
    current_plan: bool = Field(default=False, description="User's current plan")


class SubscriptionUpgradeRequest(BaseModel):
    """Subscription upgrade request."""
    target_plan: SubscriptionPlan = Field(..., description="Target subscription plan")
    payment_method_id: Optional[str] = Field(None, description="Payment method ID")
    annual_billing: bool = Field(default=False, description="Annual billing (20% discount)")
    promo_code: Optional[str] = Field(None, description="Promotional code")


class UsageCheckRequest(BaseModel):
    """Usage limit check request."""
    action_type: str = Field(..., description="Type of action to check")
    resource_count: int = Field(default=1, description="Number of resources requested")


class ConversionPromptResponse(BaseModel):
    """Conversion prompt for free users."""
    show_prompt: bool = Field(..., description="Whether to show upgrade prompt")
    title: str = Field(..., description="Prompt title")
    message: str = Field(..., description="Prompt message")
    cta_text: str = Field(..., description="Call-to-action text")
    cta_url: str = Field(..., description="Upgrade URL")
    recommended_plan: SubscriptionPlan = Field(..., description="Recommended plan")
    discount_available: bool = Field(default=False, description="Discount available")
    urgency_text: Optional[str] = Field(None, description="Urgency message")


@router.get("/plans", response_model=List[PlanResponse])
async def get_subscription_plans(
    current_user: Optional[User] = Depends(get_current_user)
) -> List[PlanResponse]:
    """
    Get all available subscription plans with pricing and features.
    
    Returns:
        List of subscription plans with details
    """
    try:
        logger.info("Fetching subscription plans", user_id=current_user.id if current_user else None)
        
        plans = []
        current_user_plan = current_user.subscription_plan if current_user else SubscriptionPlan.FREE
        
        for plan_id, plan_data in SUBSCRIPTION_PLANS.items():
            plans.append(PlanResponse(
                plan_id=plan_id,
                name=plan_data["name"],
                description=plan_data["description"],
                price=plan_data["price"],
                currency=plan_data["currency"],
                billing_period=plan_data["billing_period"],
                features=plan_data["features"],
                limits=plan_data["limits"],
                popular=plan_data["popular"],
                trial_days=plan_data["trial_days"],
                current_plan=current_user_plan == plan_id if current_user else False
            ))
        
        logger.info("Retrieved subscription plans", count=len(plans))
        return plans
        
    except Exception as e:
        logger.error("Failed to get subscription plans", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve subscription plans"
        )


@router.post("/upgrade", response_model=dict)
async def upgrade_subscription(
    upgrade_request: SubscriptionUpgradeRequest,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
) -> dict:
    """
    Upgrade user subscription to a higher plan.
    
    Args:
        upgrade_request: Upgrade details
        db: Database session
        current_user: Current user
        
    Returns:
        Upgrade result with payment details
    """
    try:
        logger.info("Processing subscription upgrade", 
                   user_id=current_user.id,
                   target_plan=upgrade_request.target_plan)
        
        # Validate target plan
        if upgrade_request.target_plan not in SUBSCRIPTION_PLANS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid subscription plan"
            )
        
        target_plan_data = SUBSCRIPTION_PLANS[upgrade_request.target_plan]
        
        # Check if this is actually an upgrade
        current_plan_value = _get_plan_value(current_user.subscription_plan or SubscriptionPlan.FREE)
        target_plan_value = _get_plan_value(upgrade_request.target_plan)
        
        if target_plan_value <= current_plan_value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Can only upgrade to a higher plan"
            )
        
        # Calculate pricing
        price = target_plan_data["price"]
        if upgrade_request.annual_billing:
            price = price * 12 * 0.8  # 20% discount for annual
        
        # In a real implementation, integrate with payment processor (Stripe, etc.)
        # For now, simulate successful payment
        payment_result = await _process_payment(
            user_id=current_user.id,
            amount=price,
            plan=upgrade_request.target_plan,
            payment_method_id=upgrade_request.payment_method_id
        )
        
        if payment_result["success"]:
            # Update user subscription
            await db.execute(
                update(User)
                .where(User.id == current_user.id)
                .values(
                    subscription_plan=upgrade_request.target_plan,
                    subscription_status="active",
                    subscription_start_date=datetime.utcnow(),
                    subscription_end_date=datetime.utcnow() + timedelta(days=30 if not upgrade_request.annual_billing else 365),
                    updated_at=datetime.utcnow()
                )
            )
            await db.commit()
            
            logger.info("Subscription upgraded successfully", 
                       user_id=current_user.id,
                       new_plan=upgrade_request.target_plan)
            
            return {
                "success": True,
                "message": f"Successfully upgraded to {target_plan_data['name']}",
                "new_plan": upgrade_request.target_plan,
                "billing_amount": price,
                "next_billing_date": (datetime.utcnow() + timedelta(days=30 if not upgrade_request.annual_billing else 365)).isoformat(),
                "payment_id": payment_result["payment_id"]
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail=f"Payment failed: {payment_result['error']}"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Subscription upgrade failed", error=str(e), user_id=current_user.id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process subscription upgrade"
        )


@router.post("/check-usage", response_model=UsageLimitCheck)
async def check_usage_limits(
    usage_request: UsageCheckRequest,
    current_user: User = Depends(get_current_user)
) -> UsageLimitCheck:
    """
    Check if user can perform an action based on their usage limits.
    
    Args:
        usage_request: Usage check details
        current_user: Current user
        
    Returns:
        Usage limit check result
    """
    try:
        user_plan = current_user.subscription_plan or SubscriptionPlan.FREE
        plan_limits = SUBSCRIPTION_PLANS[user_plan]["limits"]
        
        # Get current usage (simplified - in real app, track in database)
        current_usage = _get_current_usage(current_user.id)
        
        # Check daily limit
        daily_used = current_usage.get("daily_generations", 0)
        daily_remaining = max(0, plan_limits.daily_generations - daily_used)
        
        # Check monthly limit  
        monthly_used = current_usage.get("monthly_generations", 0)
        monthly_remaining = max(0, plan_limits.monthly_generations - monthly_used)
        
        # Determine if action is allowed
        allowed = (
            daily_remaining >= usage_request.resource_count and
            monthly_remaining >= usage_request.resource_count
        )
        
        # Determine limit type and upgrade recommendation
        limit_type = None
        upgrade_required = False
        recommended_plan = None
        
        if not allowed:
            if daily_remaining < usage_request.resource_count:
                limit_type = "daily_limit"
            elif monthly_remaining < usage_request.resource_count:
                limit_type = "monthly_limit"
            
            # Recommend upgrade plan
            upgrade_required = True
            recommended_plan = _get_recommended_plan(user_plan)
        
        return UsageLimitCheck(
            allowed=allowed,
            remaining_today=daily_remaining,
            remaining_monthly=monthly_remaining,
            limit_type=limit_type,
            upgrade_required=upgrade_required,
            recommended_plan=recommended_plan
        )
        
    except Exception as e:
        logger.error("Usage check failed", error=str(e), user_id=current_user.id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to check usage limits"
        )


@router.get("/conversion-prompt", response_model=ConversionPromptResponse)
async def get_conversion_prompt(
    action: str = Query(..., description="Action user is trying to perform"),
    current_user: Optional[User] = Depends(get_current_user)
) -> ConversionPromptResponse:
    """
    Get conversion prompt for free users hitting limits.
    
    Args:
        action: Action that triggered the prompt
        current_user: Current user (optional)
        
    Returns:
        Conversion prompt configuration
    """
    try:
        # Only show prompt for free users or users hitting limits
        if not current_user or current_user.subscription_plan == SubscriptionPlan.FREE:
            user_plan = SubscriptionPlan.FREE
        else:
            # Check if user has hit limits
            usage_check = await check_usage_limits(
                UsageCheckRequest(action_type=action, resource_count=1),
                current_user
            )
            
            if usage_check.allowed:
                return ConversionPromptResponse(
                    show_prompt=False,
                    title="",
                    message="",
                    cta_text="",
                    cta_url="",
                    recommended_plan=SubscriptionPlan.FREE
                )
            
            user_plan = current_user.subscription_plan
        
        # Generate appropriate conversion prompt
        recommended_plan = _get_recommended_plan(user_plan)
        recommended_plan_data = SUBSCRIPTION_PLANS[recommended_plan]
        
        prompts = {
            "content_generation": {
                "title": "Upgrade to Generate More Content",
                "message": f"You've reached your {SUBSCRIPTION_PLANS[user_plan]['name']} limit. Upgrade to {recommended_plan_data['name']} to generate {recommended_plan_data['limits'].monthly_generations} pieces of content per month!",
                "cta_text": f"Upgrade to {recommended_plan_data['name']}",
                "urgency_text": "Limited time: Get 20% off annual plans!"
            },
            "campaign_creation": {
                "title": "Create More Campaigns",
                "message": f"You've reached your campaign limit. Upgrade to create up to {recommended_plan_data['limits'].max_campaigns} campaigns and organize your content better!",
                "cta_text": f"Upgrade Now",
                "urgency_text": "Start your free trial today!"
            }
        }
        
        prompt_config = prompts.get(action, prompts["content_generation"])
        
        return ConversionPromptResponse(
            show_prompt=True,
            title=prompt_config["title"],
            message=prompt_config["message"],
            cta_text=prompt_config["cta_text"],
            cta_url="/pricing",
            recommended_plan=recommended_plan,
            discount_available=True,
            urgency_text=prompt_config.get("urgency_text")
        )
        
    except Exception as e:
        logger.error("Failed to get conversion prompt", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get conversion prompt"
        )


# Helper functions

def _get_plan_value(plan: SubscriptionPlan) -> int:
    """Get numeric value for plan comparison."""
    values = {
        SubscriptionPlan.FREE: 0,
        SubscriptionPlan.BASIC: 1,
        SubscriptionPlan.PRO: 2,
        SubscriptionPlan.ENTERPRISE: 3
    }
    return values.get(plan, 0)


def _get_recommended_plan(current_plan: SubscriptionPlan) -> SubscriptionPlan:
    """Get recommended upgrade plan."""
    recommendations = {
        SubscriptionPlan.FREE: SubscriptionPlan.BASIC,
        SubscriptionPlan.BASIC: SubscriptionPlan.PRO,
        SubscriptionPlan.PRO: SubscriptionPlan.ENTERPRISE,
        SubscriptionPlan.ENTERPRISE: SubscriptionPlan.ENTERPRISE
    }
    return recommendations.get(current_plan, SubscriptionPlan.BASIC)


async def _process_payment(
    user_id: int,
    amount: float,
    plan: SubscriptionPlan,
    payment_method_id: Optional[str] = None
) -> Dict[str, Any]:
    """
    Process payment (mock implementation).
    
    In a real implementation, this would integrate with:
    - Stripe
    - PayPal  
    - Other payment processors
    """
    # Simulate payment processing
    import uuid
    import asyncio
    
    # Simulate processing delay
    await asyncio.sleep(1)
    
    # Mock successful payment
    return {
        "success": True,
        "payment_id": f"pay_{uuid.uuid4().hex[:12]}",
        "amount": amount,
        "currency": "USD",
        "status": "completed"
    }


def _get_current_usage(user_id: int) -> Dict[str, int]:
    """
    Get current user usage statistics (mock implementation).
    
    In a real implementation, this would query usage from database.
    """
    # Mock usage data
    return {
        "daily_generations": 2,
        "monthly_generations": 8,
        "total_campaigns": 1,
        "total_content": 15
    } 