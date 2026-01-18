type PageHeaderProps = {
  title: string
  subtitle?: string
  action?: React.ReactNode
}

export default function PageHeader({ title, subtitle, action }: PageHeaderProps) {
  return (
    <div className="flex justify-between items-start mb-12">
      <div>
        <h1 className="text-h1 font-bold text-text-primary tracking-tight">{title}</h1>
        {subtitle && <p className="text-body text-text-secondary mt-2">{subtitle}</p>}
      </div>
      {action && <div>{action}</div>}
    </div>
  )
}
