import PageHeader from '@/components/PageHeader'
import KPIStat from '@/components/ui/KPIStat'
import Card from '@/components/ui/Card'
import dashboardData from '@/mock-data/dashboard.json'

export default function CustomerDashboard() {
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
