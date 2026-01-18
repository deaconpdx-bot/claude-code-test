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
    { label: 'Invoices', href: '/customer/invoices' },
    { label: 'Inventory', href: '/customer/inventory' },
    { label: 'Projects', href: '/customer/projects' },
  ]

  const internalNav: NavItem[] = [
    { label: 'Leads', href: '/internal/leads' },
  ]

  const navItems = mode === 'customer' ? customerNav : internalNav

  return (
    <div className="w-60 bg-surface border-r border-border-subtle min-h-screen flex flex-col">
      <div className="p-8 border-b border-border-subtle">
        <h1 className="text-h3 font-bold text-text-primary tracking-tight">Stone Forest</h1>
        <p className="text-caption text-text-tertiary mt-1 uppercase tracking-wider">
          {mode === 'customer' ? 'Customer Portal' : 'Internal Tools'}
        </p>
      </div>

      <nav className="flex-1 p-6">
        <ul className="space-y-1">
          {navItems.map((item) => {
            const isActive = pathname === item.href || pathname?.startsWith(item.href + '/')
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={`block px-4 py-3 rounded-md transition-all duration-150 ${
                    isActive
                      ? 'bg-white text-text-inverse font-medium'
                      : 'text-text-secondary hover:bg-surface-raised hover:text-text-primary'
                  }`}
                >
                  {item.label}
                </Link>
              </li>
            )
          })}
        </ul>
      </nav>

      <div className="p-6 border-t border-border-subtle">
        <div className="text-caption text-text-tertiary">
          <p className="uppercase tracking-wider mb-3">Mode: {mode === 'customer' ? 'Customer' : 'Internal'}</p>
          <Link
            href={mode === 'customer' ? '/internal/leads' : '/customer/dashboard'}
            className="text-text-primary hover:text-white transition-colors duration-150 block text-body-sm"
          >
            Switch to {mode === 'customer' ? 'Internal' : 'Customer'} →
          </Link>
        </div>
      </div>
    </div>
  )
}
