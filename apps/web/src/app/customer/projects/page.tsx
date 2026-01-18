import Link from 'next/link'
import PageHeader from '@/components/PageHeader'
import Card from '@/components/ui/Card'
import Badge from '@/components/ui/Badge'
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
          const badgeVariant = {
            in_progress: 'default' as const,
            awaiting_approval: 'active' as const,
            completed: 'muted' as const,
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
              className="block"
            >
              <Card hover>
                <div className="flex justify-between items-start mb-6">
                  <div>
                    <h3 className="text-h3 font-semibold text-text-primary">
                      {project.name}
                    </h3>
                    <p className="text-body-sm text-text-secondary mt-2">
                      {project.customer}
                    </p>
                  </div>
                  <Badge variant={badgeVariant[project.status as keyof typeof badgeVariant]}>
                    {statusLabels[project.status as keyof typeof statusLabels]}
                  </Badge>
                </div>

                <div className="grid grid-cols-4 gap-6 pt-6 border-t border-border">
                  <div>
                    <p className="text-caption text-text-tertiary uppercase tracking-wider">Files</p>
                    <p className="text-h3 font-semibold text-text-primary mt-2">
                      {project.filesCount}
                    </p>
                  </div>
                  <div>
                    <p className="text-caption text-text-tertiary uppercase tracking-wider">Pending</p>
                    <p className="text-h3 font-semibold text-text-primary mt-2">
                      {project.pendingApprovals}
                    </p>
                  </div>
                  <div>
                    <p className="text-caption text-text-tertiary uppercase tracking-wider">ETA</p>
                    <p className="text-body font-medium text-text-primary mt-2">
                      {new Date(project.eta).toLocaleDateString()}
                    </p>
                  </div>
                  <div>
                    <p className="text-caption text-text-tertiary uppercase tracking-wider">Created</p>
                    <p className="text-body font-medium text-text-secondary mt-2">
                      {new Date(project.createdAt).toLocaleDateString()}
                    </p>
                  </div>
                </div>
              </Card>
            </Link>
          )
        })}
      </div>
    </div>
  )
}
