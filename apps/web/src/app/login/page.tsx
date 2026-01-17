'use client'

import { useRouter } from 'next/navigation'
import Button from '@/components/ui/Button'
import Input from '@/components/ui/Input'
import Card from '@/components/ui/Card'

export default function LoginPage() {
  const router = useRouter()

  const handleLogin = () => {
    router.push('/customer/dashboard')
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-6">
      <div className="w-full max-w-md">
        <div className="text-center mb-12">
          <h1 className="text-display font-bold text-text-primary tracking-tight mb-3">
            Stone Forest
          </h1>
          <p className="text-body text-text-secondary">Customer Portal & Internal Tools</p>
        </div>

        <Card className="p-8">
          <div className="space-y-6">
            <div>
              <label className="block text-caption text-text-secondary uppercase tracking-wider mb-3">
                Email
              </label>
              <Input
                type="email"
                placeholder="your@email.com"
                defaultValue="demo@customer.com"
              />
            </div>

            <div>
              <label className="block text-caption text-text-secondary uppercase tracking-wider mb-3">
                Password
              </label>
              <Input
                type="password"
                placeholder="••••••••"
                defaultValue="password"
              />
            </div>

            <Button
              onClick={handleLogin}
              className="w-full"
              size="lg"
            >
              Sign In (Demo)
            </Button>

            <p className="text-caption text-text-tertiary text-center pt-4">
              This is a prototype - click &quot;Sign In&quot; to view the customer portal
            </p>
          </div>
        </Card>
      </div>
    </div>
  )
}
