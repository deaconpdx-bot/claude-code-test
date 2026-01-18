import PageHeader from '@/components/PageHeader'
import KPIStat from '@/components/ui/KPIStat'
import Card from '@/components/ui/Card'
import Badge from '@/components/ui/Badge'
import dashboardData from '@/mock-data/dashboard.json'
import invoicesData from '@/mock-data/invoices.json'

export default function CustomerDashboard() {
  // Calculate invoice metrics
  const today = new Date()
  today.setHours(0, 0, 0, 0)

  const paidCount = invoicesData.filter(inv => inv.status === 'paid').length
  const dueSoonCount = invoicesData.filter(inv => {
    const dueDate = new Date(inv.due_date)
    const diffDays = Math.ceil((dueDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
    return inv.status === 'sent' && diffDays > 0 && diffDays <= 7
  }).length
  const dueTodayCount = invoicesData.filter(inv => {
    const dueDate = new Date(inv.due_date)
    dueDate.setHours(0, 0, 0, 0)
    return inv.status === 'sent' && dueDate.getTime() === today.getTime()
  }).length
  const pastDueCount = invoicesData.filter(inv => inv.status === 'overdue').length

  return (
    <div>
      <PageHeader
        title="Dashboard"
        subtitle="Overview of your account activity"
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        <KPIStat
          label="Inventory Alerts"
          value={dashboardData.inventoryAlerts}
          description="Items need attention"
        />

        <KPIStat
          label="Active Projects"
          value={dashboardData.activeProjects}
          description="In progress"
        />

        <KPIStat
          label="Pending Approvals"
          value={dashboardData.pendingApprovals}
          description="Awaiting your review"
        />
      </div>

      <div className="mb-12">
        <h2 className="text-h2 font-semibold text-text-primary mb-6">Invoices</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <KPIStat
            label="Paid"
            value={paidCount}
            description="Invoices paid"
          />

          <KPIStat
            label="Due Soon"
            value={dueSoonCount}
            description="Within 7 days"
          />

          <KPIStat
            label="Due Today"
            value={dueTodayCount}
            description="Payment due"
          />

          <KPIStat
            label="Past Due"
            value={pastDueCount}
            description="Requires attention"
          />
        </div>
      </div>

      <Card>
        <div className="mb-6">
          <h2 className="text-h3 font-semibold text-text-primary">Recent Alerts</h2>
        </div>
        <div className="space-y-4">
          {dashboardData.alerts.map((alert) => {
            const styles = {
              critical: 'border-l-4 border-white',
              warning: 'border-l-4 border-accent-muted',
              info: 'border-l-4 border-border-strong',
            }
            return (
              <div
                key={alert.id}
                className={`p-4 bg-surface-raised rounded-md ${styles[alert.type as keyof typeof styles]}`}
              >
                <p className="text-body text-text-primary font-medium">{alert.message}</p>
                <p className="text-caption text-text-tertiary mt-2">
                  {new Date(alert.timestamp).toLocaleString()}
                </p>
              </div>
            )
          })}
        </div>
      </Card>
    </div>
  )
}
