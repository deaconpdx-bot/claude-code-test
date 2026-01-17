'use client'

import { HTMLAttributes, ReactNode, useEffect } from 'react'
import { cn } from '@/lib/utils'

interface ModalProps extends HTMLAttributes<HTMLDivElement> {
  isOpen: boolean
  onClose: () => void
  title?: string
  children: ReactNode
}

export default function Modal({ isOpen, onClose, title, children, className }: ModalProps) {
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = 'unset'
    }
    return () => {
      document.body.style.overflow = 'unset'
    }
  }, [isOpen])

  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 animate-fade-in"
      onClick={onClose}
    >
      <div
        className={cn(
          'bg-surface-overlay rounded-xl shadow-xl max-w-lg w-full mx-4 animate-slide-up',
          className
        )}
        onClick={(e) => e.stopPropagation()}
      >
        {title && (
          <div className="px-8 pt-8 pb-6 border-b border-border">
            <h2 className="text-h3 text-text-primary">{title}</h2>
          </div>
        )}
        <div className="p-8">{children}</div>
      </div>
    </div>
  )
}
