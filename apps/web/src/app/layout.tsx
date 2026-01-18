import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Stone Forest App',
  description: 'Customer Portal & Internal Tools',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
