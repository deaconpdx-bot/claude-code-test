import Sidebar from '@/components/Sidebar'

export default function CustomerLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar mode="customer" />
      <main className="flex-1 p-12 max-w-7xl">
        {children}
      </main>
    </div>
  )
}
