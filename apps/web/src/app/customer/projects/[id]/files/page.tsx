'use client'

import { useState } from 'next/core'
import { useParams, useRouter } from 'next/navigation'
import PageHeader from '@/components/PageHeader'
import projectsData from '@/mock-data/projects.json'
import filesData from '@/mock-data/files.json'

export default function ProjectFilesPage() {
  const params = useParams()
  const router = useRouter()
  const projectId = params.id as string

  const project = projectsData.find((p) => p.id === projectId)
  const files = (filesData as Record<string, any[]>)[projectId] || []

  const [showUploadModal, setShowUploadModal] = useState(false)
  const [selectedFile, setSelectedFile] = useState<any>(null)

  if (!project) {
    return <div>Project not found</div>
  }

  const handleApprove = (file: any) => {
    alert(`Approved: ${file.name}`)
    setSelectedFile(null)
  }

  const handleReject = (file: any) => {
    alert(`Requested changes for: ${file.name}`)
    setSelectedFile(null)
  }

  return (
    <div>
      <PageHeader
        title={project.name}
        subtitle={`${files.length} files`}
        action={
          <button
            onClick={() => setShowUploadModal(true)}
            className="bg-blue-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors"
          >
            Upload File
          </button>
        }
      />

      <div className="grid grid-cols-1 gap-4">
        {files.map((file) => (
          <div
            key={file.id}
            className="bg-white p-6 rounded-lg shadow-sm border border-gray-200"
          >
            <div className="flex justify-between items-start">
              <div className="flex-1">
                <div className="flex items-center gap-3">
                  <h3 className="text-lg font-semibold text-gray-900">
                    {file.name}
                  </h3>
                  <span className="px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded">
                    {file.version}
                  </span>
                  {file.status === 'approved' && (
                    <span className="px-2 py-1 text-xs font-medium bg-green-100 text-green-800 rounded">
                      ✓ Approved
                    </span>
                  )}
                  {file.status === 'pending_approval' && (
                    <span className="px-2 py-1 text-xs font-medium bg-orange-100 text-orange-800 rounded">
                      ⏱ Pending
                    </span>
                  )}
                </div>
                <div className="mt-2 text-sm text-gray-600">
                  <p>Uploaded by {file.uploadedBy} • {file.size}</p>
                  <p className="text-xs mt-1">
                    {new Date(file.uploadedAt).toLocaleString()}
                  </p>
                </div>

                {file.approvals && file.approvals.length > 0 && (
                  <div className="mt-4 p-3 bg-green-50 border border-green-200 rounded">
                    <p className="text-sm font-medium text-green-900">
                      Approved by {file.approvals[0].approvedBy}
                    </p>
                    {file.approvals[0].comment && (
                      <p className="text-sm text-green-700 mt-1">
                        &quot;{file.approvals[0].comment}&quot;
                      </p>
                    )}
                    <p className="text-xs text-green-600 mt-1">
                      {new Date(file.approvals[0].approvedAt).toLocaleString()}
                    </p>
                  </div>
                )}
              </div>

              {file.status === 'pending_approval' && (
                <div className="flex gap-2 ml-4">
                  <button
                    onClick={() => handleApprove(file)}
                    className="px-4 py-2 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors"
                  >
                    Approve
                  </button>
                  <button
                    onClick={() => handleReject(file)}
                    className="px-4 py-2 bg-gray-600 text-white rounded-lg font-medium hover:bg-gray-700 transition-colors"
                  >
                    Request Changes
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {showUploadModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-8 max-w-md w-full">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Upload File
            </h2>

            <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center mb-6">
              <div className="text-4xl mb-4">📁</div>
              <p className="text-gray-600 mb-2">
                Click to browse or drag and drop
              </p>
              <p className="text-sm text-gray-500">
                PDF, AI, PSD, PNG, JPG up to 50MB
              </p>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setShowUploadModal(false)}
                className="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg font-medium hover:bg-gray-300 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  alert('File upload simulation - file would be uploaded here')
                  setShowUploadModal(false)
                }}
                className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
              >
                Upload
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
