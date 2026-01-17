import { HTMLAttributes, forwardRef } from 'react'
import { cn } from '@/lib/utils'
import Card from './Card'

interface KPIStatProps extends HTMLAttributes<HTMLDivElement> {
  label: string
  value: string | number
  description?: string
  trend?: 'up' | 'down' | 'neutral'
}

const KPIStat = forwardRef<HTMLDivElement, KPIStatProps>(
  ({ className, label, value, description, trend, ...props }, ref) => {
    return (
      <Card ref={ref} hover className={cn('', className)} {...props}>
        <div className="flex flex-col">
          <p className="text-caption text-text-secondary uppercase tracking-wider mb-3">
            {label}
          </p>
          <p className="text-h1 text-text-primary mb-2">{value}</p>
          {description && (
            <p className={cn(
              'text-body-sm',
              trend === 'up' && 'text-text-primary',
              trend === 'down' && 'text-text-secondary',
              !trend && 'text-text-secondary'
            )}>
              {description}
            </p>
          )}
        </div>
      </Card>
    )
  }
)

KPIStat.displayName = 'KPIStat'

export default KPIStat
