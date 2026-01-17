import PageHeader from '@/components/PageHeader'
import dashboardData from '@/mock-data/dashboard.json'

export default function CustomerDashboard() {
  return (
    <div>
      <PageHeader
        title="Dashboard"
        subtitle="Overview of your account activity"
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-700">Inventory</h3>
            <span className="text-2xl">📦</span>
          </div>
          <div className="text-3xl font-bold text-gray-900 mb-2">
            {dashboardData.inventoryAlerts}
          </div>
          <p className="text-sm text-red-600">Items need attention</p>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-700">Projects</h3>
            <span className="text-2xl">🎨</span>
          </div>
          <div className="text-3xl font-bold text-gray-900 mb-2">
            {dashboardData.activeProjects}
          </div>
          <p className="text-sm text-gray-600">Active projects</p>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-700">Approvals</h3>
            <span className="text-2xl">✓</span>
          </div>
          <div className="text-3xl font-bold text-gray-900 mb-2">
            {dashboardData.pendingApprovals}
          </div>
          <p className="text-sm text-orange-600">Pending your review</p>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Recent Alerts</h2>
        </div>
        <div className="divide-y divide-gray-200">
          {dashboardData.alerts.map((alert) => {
            const colors = {
              critical: 'bg-red-50 border-red-200 text-red-800',
              warning: 'bg-orange-50 border-orange-200 text-orange-800',
              info: 'bg-blue-50 border-blue-200 text-blue-800',
            }
            return (
              <div
                key={alert.id}
                className={`p-4 border-l-4 ${colors[alert.type as keyof typeof colors]}`}
              >
                <p className="font-medium">{alert.message}</p>
                <p className="text-sm text-gray-600 mt-1">
                  {new Date(alert.timestamp).toLocaleString()}
                </p>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
