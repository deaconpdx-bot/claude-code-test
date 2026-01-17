'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

type NavItem = {
  label: string
  href: string
}

type SidebarProps = {
  mode: 'customer' | 'internal'
}

export default function Sidebar({ mode }: SidebarProps) {
  const pathname = usePathname()

  const customerNav: NavItem[] = [
    { label: 'Dashboard', href: '/customer/dashboard' },
    { label: 'Inventory', href: '/customer/inventory' },
    { label: 'Projects', href: '/customer/projects' },
  ]

  const internalNav: NavItem[] = [
    { label: 'Leads', href: '/internal/leads' },
  ]

  const navItems = mode === 'customer' ? customerNav : internalNav

  return (
    <div className="w-64 bg-gray-900 text-white min-h-screen flex flex-col">
      <div className="p-6 border-b border-gray-700">
        <h1 className="text-xl font-bold">Stone Forest</h1>
        <p className="text-sm text-gray-400 mt-1">
          {mode === 'customer' ? 'Customer Portal' : 'Internal Tools'}
        </p>
      </div>

      <nav className="flex-1 p-4">
        <ul className="space-y-2">
          {navItems.map((item) => {
            const isActive = pathname === item.href || pathname?.startsWith(item.href + '/')
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={`block px-4 py-2 rounded-lg transition-colors ${
                    isActive
                      ? 'bg-blue-600 text-white'
                      : 'text-gray-300 hover:bg-gray-800'
                  }`}
                >
                  {item.label}
                </Link>
              </li>
            )
          })}
        </ul>
      </nav>

      <div className="p-4 border-t border-gray-700">
        <div className="text-sm text-gray-400">
          <p>Mode: {mode === 'customer' ? 'Customer' : 'Internal'}</p>
          <Link
            href={mode === 'customer' ? '/internal/leads' : '/customer/dashboard'}
            className="text-blue-400 hover:underline mt-2 block"
          >
            Switch to {mode === 'customer' ? 'Internal' : 'Customer'}
          </Link>
        </div>
      </div>
    </div>
  )
}
