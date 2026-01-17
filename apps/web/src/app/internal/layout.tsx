import Sidebar from '@/components/Sidebar'

export default function InternalLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar mode="internal" />
      <main className="flex-1 p-8">
        {children}
      </main>
    </div>
  )
}
