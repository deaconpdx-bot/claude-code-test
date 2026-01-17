'use client'

import { useState } from 'react'
import { useParams } from 'next/navigation'
import PageHeader from '@/components/PageHeader'
import Card from '@/components/ui/Card'
import Badge from '@/components/ui/Badge'
import Button from '@/components/ui/Button'
import Modal from '@/components/ui/Modal'
import projectsData from '@/mock-data/projects.json'
import filesData from '@/mock-data/files.json'

export default function ProjectFilesPage() {
  const params = useParams()
  const projectId = params.id as string

  const project = projectsData.find((p) => p.id === projectId)
  const files = (filesData as Record<string, any[]>)[projectId] || []

  const [showUploadModal, setShowUploadModal] = useState(false)

  if (!project) {
    return <div className="text-text-primary">Project not found</div>
  }

  const handleApprove = (file: any) => {
    alert(`Approved: ${file.name}`)
  }

  const handleReject = (file: any) => {
    alert(`Requested changes for: ${file.name}`)
  }

  return (
    <div>
      <PageHeader
        title={project.name}
        subtitle={`${files.length} files`}
        action={
          <Button onClick={() => setShowUploadModal(true)}>
            Upload File
          </Button>
        }
      />

      <div className="space-y-6">
        {files.map((file) => (
          <Card key={file.id}>
            <div className="flex justify-between items-start">
              <div className="flex-1">
                <div className="flex items-center gap-3 flex-wrap">
                  <h3 className="text-h3 font-semibold text-text-primary">
                    {file.name}
                  </h3>
                  <Badge variant="muted">{file.version}</Badge>
                  {file.status === 'approved' && (
                    <Badge variant="active">Approved</Badge>
                  )}
                  {file.status === 'pending_approval' && (
                    <Badge variant="default">Pending</Badge>
                  )}
                </div>
                <div className="mt-3 text-body-sm text-text-secondary">
                  <p>Uploaded by {file.uploadedBy} • {file.size}</p>
                  <p className="text-caption text-text-tertiary mt-1">
                    {new Date(file.uploadedAt).toLocaleString()}
                  </p>
                </div>

                {file.approvals && file.approvals.length > 0 && (
                  <div className="mt-6 p-4 bg-surface-raised border border-border rounded-md">
                    <p className="text-body-sm font-medium text-text-primary">
                      Approved by {file.approvals[0].approvedBy}
                    </p>
                    {file.approvals[0].comment && (
                      <p className="text-body-sm text-text-secondary mt-2">
                        &quot;{file.approvals[0].comment}&quot;
                      </p>
                    )}
                    <p className="text-caption text-text-tertiary mt-2">
                      {new Date(file.approvals[0].approvedAt).toLocaleString()}
                    </p>
                  </div>
                )}
              </div>

              {file.status === 'pending_approval' && (
                <div className="flex gap-3 ml-6">
                  <Button onClick={() => handleApprove(file)} variant="primary">
                    Approve
                  </Button>
                  <Button onClick={() => handleReject(file)} variant="secondary">
                    Request Changes
                  </Button>
                </div>
              )}
            </div>
          </Card>
        ))}
      </div>

      <Modal
        isOpen={showUploadModal}
        onClose={() => setShowUploadModal(false)}
        title="Upload File"
      >
        <div className="border-2 border-dashed border-border-strong rounded-lg p-12 text-center mb-6 bg-surface">
          <div className="text-h2 mb-4 text-text-secondary">+</div>
          <p className="text-body text-text-primary mb-2">
            Click to browse or drag and drop
          </p>
          <p className="text-caption text-text-tertiary">
            PDF, AI, PSD, PNG, JPG up to 50MB
          </p>
        </div>

        <div className="flex gap-3">
          <Button
            onClick={() => setShowUploadModal(false)}
            variant="secondary"
            className="flex-1"
          >
            Cancel
          </Button>
          <Button
            onClick={() => {
              alert('File upload simulation - file would be uploaded here')
              setShowUploadModal(false)
            }}
            variant="primary"
            className="flex-1"
          >
            Upload
          </Button>
        </div>
      </Modal>
    </div>
  )
}
