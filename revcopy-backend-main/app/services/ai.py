"""
AI service for content generation using various AI providers.
"""

import os
import asyncio
from typing import Optional, Dict, List
from abc import ABC, abstractmethod

import structlog
from openai import AsyncOpenAI
import httpx

from app.core.config import settings

# Configure logging
logger = structlog.get_logger(__name__)


class AIProvider(ABC):
    """Abstract base class for AI providers."""
    
    @abstractmethod
    async def generate_content(
        self, 
        prompt: str, 
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        platform: Optional[str] = None,
        cultural_context: Optional[Dict] = None,
        **kwargs
    ) -> str:
        """Generate content using the AI provider."""
        pass


class OpenAIProvider(AIProvider):
    """OpenAI API provider for content generation."""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        self.model = "gpt-4-turbo-preview"
    
    async def generate_content(
        self, 
        prompt: str, 
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        platform: Optional[str] = None,
        cultural_context: Optional[Dict] = None,
        **kwargs
    ) -> str:
        """Generate content using OpenAI API."""
        try:
            logger.info("Generating content with OpenAI", 
                       model=self.model, 
                       max_tokens=max_tokens,
                       platform=platform)
            
            # Prepare system prompt
            if not system_prompt:
                system_prompt = self._get_default_system_prompt(platform)
            
            # Add cultural context if provided
            if cultural_context:
                system_prompt += f"\n\nCultural Context: {cultural_context}"
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": prompt}
                ],
                temperature=temperature,
                max_tokens=max_tokens,
                **kwargs
            )
            
            content = response.choices[0].message.content
            logger.info("Content generated successfully", 
                       tokens_used=response.usage.total_tokens,
                       platform=platform)
            
            return content
            
        except Exception as e:
            logger.error("OpenAI content generation failed", error=str(e))
            raise Exception(f"OpenAI service unavailable: {str(e)}")
    
    def _get_default_system_prompt(self, platform: Optional[str] = None) -> str:
        """Get default system prompt based on platform."""
        base_prompt = "You are a professional marketing copywriter specializing in e-commerce content creation."
        
        if platform:
            platform_prompts = {
                "facebook": "Focus on emotional appeal and social sharing potential.",
                "instagram": "Use engaging visuals and hashtag suggestions.",
                "google": "Optimize for search intent and conversion.",
                "email": "Create compelling subject lines and personalized content.",
                "blog": "Provide valuable, informative content with SEO optimization."
            }
            base_prompt += f" {platform_prompts.get(platform, '')}"
        
        return base_prompt


class DeepSeekProvider(AIProvider):
    """DeepSeek API provider for content generation."""
    
    def __init__(self):
        self.api_key = settings.DEEPSEEK_API_KEY
        self.base_url = "https://api.deepseek.com/v1"
        self.model = "deepseek-chat"
    
    async def generate_content(
        self, 
        prompt: str, 
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        platform: Optional[str] = None,
        cultural_context: Optional[Dict] = None,
        **kwargs
    ) -> str:
        """Generate content using DeepSeek API."""
        try:
            logger.info("Generating content with DeepSeek", 
                       model=self.model, 
                       max_tokens=max_tokens,
                       platform=platform)
            
            # Prepare system prompt
            if not system_prompt:
                system_prompt = self._get_default_system_prompt(platform)
            
            # Add cultural context if provided
            if cultural_context:
                system_prompt += f"\n\nCultural Context: {cultural_context}"
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": prompt}
                        ],
                        "temperature": temperature,
                        "max_tokens": max_tokens,
                        **kwargs
                    },
                    timeout=60.0
                )
                
                if response.status_code != 200:
                    raise Exception(f"DeepSeek API error: {response.status_code} - {response.text}")
                
                data = response.json()
                content = data["choices"][0]["message"]["content"]
                
                logger.info("Content generated successfully with DeepSeek", 
                           tokens_used=data.get("usage", {}).get("total_tokens", 0),
                           platform=platform)
                
                return content
                
        except Exception as e:
            logger.error("DeepSeek content generation failed", error=str(e))
            raise Exception(f"DeepSeek service unavailable: {str(e)}")
    
    def _get_default_system_prompt(self, platform: Optional[str] = None) -> str:
        """Get default system prompt based on platform."""
        base_prompt = "You are a professional marketing copywriter specializing in e-commerce content creation."
        
        if platform:
            platform_prompts = {
                "facebook": "Focus on emotional appeal and social sharing potential.",
                "instagram": "Use engaging visuals and hashtag suggestions.",
                "google": "Optimize for search intent and conversion.",
                "email": "Create compelling subject lines and personalized content.",
                "blog": "Provide valuable, informative content with SEO optimization."
            }
            base_prompt += f" {platform_prompts.get(platform, '')}"
        
        return base_prompt


class AIService:
    """Main AI service for content generation."""
    
    def __init__(self):
        self.providers = {}
        self._initialize_providers()
    
    def _initialize_providers(self):
        """Initialize available AI providers."""
        try:
            if settings.OPENAI_API_KEY:
                self.providers["openai"] = OpenAIProvider()
                logger.info("OpenAI provider initialized")
        except Exception as e:
            logger.warning("Failed to initialize OpenAI provider", error=str(e))
        
        try:
            if settings.DEEPSEEK_API_KEY:
                self.providers["deepseek"] = DeepSeekProvider()
                logger.info("DeepSeek provider initialized")
        except Exception as e:
            logger.warning("Failed to initialize DeepSeek provider", error=str(e))
        
        if not self.providers:
            logger.error("No AI providers available")
            raise Exception("No AI providers configured")
    
    async def generate_content(
        self, 
        prompt: str, 
        provider: str = "auto",
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        platform: Optional[str] = None,
        cultural_context: Optional[Dict] = None,
        **kwargs
    ) -> str:
        """Generate content using the specified or best available provider."""
        try:
            # Determine which provider to use
            if provider == "auto":
                # Try providers in order of preference
                preferred_order = ["openai", "deepseek"]
                for preferred_provider in preferred_order:
                    if preferred_provider in self.providers:
                        provider = preferred_provider
                        break
                else:
                    # Use first available provider
                    provider = list(self.providers.keys())[0]
            
            if provider not in self.providers:
                raise Exception(f"Provider '{provider}' not available")
            
            ai_provider = self.providers[provider]
            
            logger.info("Generating content", 
                       provider=provider,
                       platform=platform,
                       max_tokens=max_tokens)
            
            content = await ai_provider.generate_content(
                prompt=prompt,
                system_prompt=system_prompt,
                temperature=temperature,
                max_tokens=max_tokens,
                platform=platform,
                cultural_context=cultural_context,
                **kwargs
            )
            
            return content
            
        except Exception as e:
            logger.error("Content generation failed", error=str(e))
            raise Exception(f"Content generation failed: {str(e)}")
    
    async def generate_multiple_versions(
        self,
        prompt: str,
        count: int = 3,
        provider: str = "auto",
        system_prompt: Optional[str] = None,
        temperature: float = 0.8,
        max_tokens: int = 1000,
        platform: Optional[str] = None,
        **kwargs
    ) -> List[str]:
        """Generate multiple content versions."""
        try:
            versions = []
            
            for i in range(count):
                # Vary temperature slightly for different versions
                version_temperature = temperature + (i * 0.1)
                
                content = await self.generate_content(
                    prompt=prompt,
                    provider=provider,
                    system_prompt=system_prompt,
                    temperature=version_temperature,
                    max_tokens=max_tokens,
                    platform=platform,
                    **kwargs
                )
                
                versions.append(content)
            
            logger.info("Generated multiple content versions", count=len(versions))
            return versions
            
        except Exception as e:
            logger.error("Multiple version generation failed", error=str(e))
            raise Exception(f"Multiple version generation failed: {str(e)}")
    
    def get_available_providers(self) -> List[str]:
        """Get list of available AI providers."""
        return list(self.providers.keys())
    
    def is_provider_available(self, provider: str) -> bool:
        """Check if a specific provider is available."""
        return provider in self.providers

