import Link from 'next/link'
import PageHeader from '@/components/PageHeader'
import projectsData from '@/mock-data/projects.json'

export default function ProjectsPage() {
  return (
    <div>
      <PageHeader
        title="Projects"
        subtitle="View and manage your active projects"
      />

      <div className="grid grid-cols-1 gap-6">
        {projectsData.map((project) => {
          const statusColors = {
            in_progress: 'bg-blue-100 text-blue-800',
            awaiting_approval: 'bg-orange-100 text-orange-800',
            completed: 'bg-green-100 text-green-800',
          }

          const statusLabels = {
            in_progress: 'In Progress',
            awaiting_approval: 'Awaiting Approval',
            completed: 'Completed',
          }

          return (
            <Link
              key={project.id}
              href={`/customer/projects/${project.id}/files`}
              className="block bg-white p-6 rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow"
            >
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-xl font-semibold text-gray-900">
                    {project.name}
                  </h3>
                  <p className="text-sm text-gray-600 mt-1">
                    {project.customer}
                  </p>
                </div>
                <span className={`px-3 py-1 text-xs font-semibold rounded-full ${statusColors[project.status as keyof typeof statusColors]}`}>
                  {statusLabels[project.status as keyof typeof statusLabels]}
                </span>
              </div>

              <div className="grid grid-cols-4 gap-4 pt-4 border-t border-gray-200">
                <div>
                  <p className="text-xs text-gray-500">Files</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {project.filesCount}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-gray-500">Pending Approvals</p>
                  <p className="text-lg font-semibold text-orange-600">
                    {project.pendingApprovals}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-gray-500">ETA</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {new Date(project.eta).toLocaleDateString()}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-gray-500">Created</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {new Date(project.createdAt).toLocaleDateString()}
                  </p>
                </div>
              </div>
            </Link>
          )
        })}
      </div>
    </div>
  )
}
