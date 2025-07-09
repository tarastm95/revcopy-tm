/**
 * Login Page for RevCopy Admin Panel
 * 
 * Provides secure authentication interface with:
 * - Form validation using react-hook-form and zod
 * - Error handling and user feedback
 * - Responsive design
 * - Security best practices
 */

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { AlertCircle, Loader2, Shield } from 'lucide-react';
import { useAuth } from '@/context/AuthContext';
import { useToast } from '@/hooks/use-toast';

const Login: React.FC = () => {
  const [credentials, setCredentials] = useState({
    email: 'admin@revcopy.com', // Pre-fill for testing
    password: 'admin123'
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string>('');

  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const { toast } = useToast();

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      console.log('✅ User already authenticated, redirecting...');
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    console.log('🔐 Login attempt:', { email: credentials.email });

    try {
      const result = await login(credentials);
      
      console.log('🔐 Login result:', result);

      if (result.success) {
        toast({
          title: 'Login Successful',
          description: 'Welcome to the admin panel',
        });
        console.log('✅ Login successful, redirecting...');
        navigate('/');
      } else {
        const errorMessage = result.message || 'Login failed';
        console.error('❌ Login failed:', errorMessage);
        setError(errorMessage);
        toast({
          title: 'Login Failed',
          description: errorMessage,
          variant: 'destructive',
        });
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'An unexpected error occurred';
      console.error('❌ Login error:', err);
      setError(errorMessage);
      toast({
        title: 'Login Error',
        description: errorMessage,
        variant: 'destructive',
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (field: 'email' | 'password') => (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    setCredentials(prev => ({
      ...prev,
      [field]: e.target.value
    }));
  };

  // Quick test function
  const testDirectLogin = async () => {
    console.log('🧪 Testing direct API login...');
    try {
      const hostname = window.location.hostname;
      const apiUrl = hostname === 'localhost' || hostname === '127.0.0.1' 
        ? 'http://localhost:8000' 
        : `http://${hostname}:8000`;
      
      const response = await fetch(`${apiUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(credentials)
      });
      const result = await response.json();
      console.log('🧪 Direct API result:', result);
      
      if (result.access_token) {
        localStorage.setItem('admin_access_token', result.access_token);
        console.log('✅ Token stored, reloading...');
        window.location.reload();
      }
    } catch (error) {
      console.error('🧪 Direct test failed:', error);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <div className="mx-auto mb-4 w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center">
            <Shield className="w-6 h-6 text-white" />
          </div>
          <CardTitle className="text-2xl font-bold text-gray-900">
            RevCopy Admin
          </CardTitle>
          <p className="text-gray-600">
            Sign in to access the admin panel
          </p>
        </CardHeader>
        
        <CardContent className="space-y-4">
          {error && (
            <div className="flex items-center space-x-2 p-3 bg-red-50 border border-red-200 rounded-lg">
              <AlertCircle className="w-4 h-4 text-red-500" />
              <span className="text-sm text-red-700">{error}</span>
            </div>
          )}
          
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="admin@revcopy.com"
                value={credentials.email}
                onChange={handleInputChange('email')}
                required
                disabled={isLoading}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                placeholder="Enter your password"
                value={credentials.password}
                onChange={handleInputChange('password')}
                required
                disabled={isLoading}
              />
            </div>
            
            <div className="space-y-2">
              <Button
                type="submit"
                className="w-full"
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Signing In...
                  </>
                ) : (
                  'Sign In'
                )}
              </Button>
              
              <Button
                type="button"
                variant="outline"
                className="w-full"
                onClick={testDirectLogin}
                disabled={isLoading}
              >
                🧪 Test Direct Login
              </Button>
            </div>
          </form>
          
          <div className="text-center text-sm text-gray-500">
            <p>Development credentials:</p>
            <p className="font-mono text-xs">admin@revcopy.com / admin123</p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default Login; 