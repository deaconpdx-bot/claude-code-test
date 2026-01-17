'use client'

import { useState } from 'react'
import PageHeader from '@/components/PageHeader'
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/Table'
import Badge from '@/components/ui/Badge'
import Card from '@/components/ui/Card'
import Modal from '@/components/ui/Modal'
import Button from '@/components/ui/Button'
import invoicesData from '@/mock-data/invoices.json'

type Invoice = typeof invoicesData[0]

export default function InvoicesPage() {
  const [selectedInvoice, setSelectedInvoice] = useState<Invoice | null>(null)

  const formatCurrency = (cents: number) => {
    return `$${(cents / 100).toFixed(2)}`
  }

  const getStatusVariant = (status: string) => {
    switch (status) {
      case 'paid':
        return 'muted' as const
      case 'overdue':
        return 'active' as const
      case 'sent':
        return 'default' as const
      default:
        return 'muted' as const
    }
  }

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'paid':
        return 'Paid'
      case 'overdue':
        return 'Overdue'
      case 'sent':
        return 'Sent'
      case 'draft':
        return 'Draft'
      case 'cancelled':
        return 'Cancelled'
      default:
        return status
    }
  }

  return (
    <div>
      <PageHeader
        title="Invoices"
        subtitle="View and manage your invoices"
      />

      <Card className="p-0 overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Invoice #</TableHead>
              <TableHead>Project</TableHead>
              <TableHead>Issue Date</TableHead>
              <TableHead>Due Date</TableHead>
              <TableHead className="text-right">Total</TableHead>
              <TableHead className="text-right">Paid</TableHead>
              <TableHead className="text-right">Balance</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Deposit</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {invoicesData.map((invoice) => (
              <TableRow
                key={invoice.id}
                className="cursor-pointer"
                onClick={() => setSelectedInvoice(invoice)}
              >
                <TableCell className="font-medium">{invoice.invoice_number}</TableCell>
                <TableCell>{invoice.project_name}</TableCell>
                <TableCell className="text-text-secondary">
                  {new Date(invoice.issue_date).toLocaleDateString()}
                </TableCell>
                <TableCell className="text-text-secondary">
                  {new Date(invoice.due_date).toLocaleDateString()}
                </TableCell>
                <TableCell className="text-right font-medium">
                  {formatCurrency(invoice.amount_total)}
                </TableCell>
                <TableCell className="text-right text-text-secondary">
                  {formatCurrency(invoice.amount_paid)}
                </TableCell>
                <TableCell className={`text-right font-medium ${invoice.balance_due > 0 ? 'text-text-primary' : 'text-text-secondary'}`}>
                  {formatCurrency(invoice.balance_due)}
                </TableCell>
                <TableCell>
                  <Badge variant={getStatusVariant(invoice.status)}>
                    {getStatusLabel(invoice.status)}
                  </Badge>
                </TableCell>
                <TableCell>
                  {invoice.deposit_required && (
                    <Badge variant={invoice.deposit_paid ? 'muted' : 'default'}>
                      {invoice.deposit_paid ? 'Paid' : 'Required'}
                    </Badge>
                  )}
                  {!invoice.deposit_required && (
                    <span className="text-caption text-text-tertiary">—</span>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Card>

      {selectedInvoice && (
        <Modal
          isOpen={!!selectedInvoice}
          onClose={() => setSelectedInvoice(null)}
          title={`Invoice ${selectedInvoice.invoice_number}`}
          className="max-w-2xl"
        >
          <div className="space-y-6">
            {/* Header Info */}
            <div className="grid grid-cols-2 gap-6">
              <div>
                <p className="text-caption text-text-tertiary uppercase tracking-wider mb-2">
                  Customer
                </p>
                <p className="text-body text-text-primary font-medium">
                  {selectedInvoice.customer_name}
                </p>
              </div>
              <div>
                <p className="text-caption text-text-tertiary uppercase tracking-wider mb-2">
                  Project
                </p>
                <p className="text-body text-text-primary font-medium">
                  {selectedInvoice.project_name}
                </p>
              </div>
            </div>

            {/* Dates */}
            <div className="grid grid-cols-2 gap-6">
              <div>
                <p className="text-caption text-text-tertiary uppercase tracking-wider mb-2">
                  Issue Date
                </p>
                <p className="text-body text-text-primary">
                  {new Date(selectedInvoice.issue_date).toLocaleDateString()}
                </p>
              </div>
              <div>
                <p className="text-caption text-text-tertiary uppercase tracking-wider mb-2">
                  Due Date
                </p>
                <p className="text-body text-text-primary">
                  {new Date(selectedInvoice.due_date).toLocaleDateString()}
                </p>
              </div>
            </div>

            {/* Amounts */}
            <div className="border-t border-border pt-6">
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-body text-text-secondary">Subtotal</span>
                  <span className="text-body text-text-primary">
                    {formatCurrency(selectedInvoice.amount_subtotal)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-body text-text-secondary">Tax</span>
                  <span className="text-body text-text-primary">
                    {formatCurrency(selectedInvoice.amount_tax)}
                  </span>
                </div>
                <div className="flex justify-between pt-3 border-t border-border">
                  <span className="text-body-lg font-semibold text-text-primary">Total</span>
                  <span className="text-body-lg font-semibold text-text-primary">
                    {formatCurrency(selectedInvoice.amount_total)}
                  </span>
                </div>
                {selectedInvoice.amount_paid > 0 && (
                  <>
                    <div className="flex justify-between">
                      <span className="text-body text-text-secondary">Paid</span>
                      <span className="text-body text-text-primary">
                        {formatCurrency(selectedInvoice.amount_paid)}
                      </span>
                    </div>
                    <div className="flex justify-between pt-3 border-t border-border">
                      <span className="text-body-lg font-semibold text-text-primary">Balance Due</span>
                      <span className="text-body-lg font-semibold text-text-primary">
                        {formatCurrency(selectedInvoice.balance_due)}
                      </span>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Deposit Info */}
            {selectedInvoice.deposit_required && (
              <div className="border-t border-border pt-6">
                <p className="text-caption text-text-tertiary uppercase tracking-wider mb-3">
                  Deposit Information
                </p>
                <div className="bg-surface-raised p-4 rounded-md">
                  <div className="flex justify-between items-center mb-2">
                    <span className="text-body text-text-primary">Deposit Amount</span>
                    <span className="text-body font-medium text-text-primary">
                      {formatCurrency(selectedInvoice.deposit_amount || 0)}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-body text-text-primary">Deposit Status</span>
                    <Badge variant={selectedInvoice.deposit_paid ? 'muted' : 'active'}>
                      {selectedInvoice.deposit_paid ? 'Paid' : 'Required'}
                    </Badge>
                  </div>
                  {selectedInvoice.deposit_paid && selectedInvoice.deposit_paid_at && (
                    <p className="text-caption text-text-tertiary mt-2">
                      Paid on {new Date(selectedInvoice.deposit_paid_at).toLocaleDateString()}
                    </p>
                  )}
                </div>
              </div>
            )}

            {/* Notes */}
            {selectedInvoice.notes && (
              <div className="border-t border-border pt-6">
                <p className="text-caption text-text-tertiary uppercase tracking-wider mb-2">
                  Notes
                </p>
                <p className="text-body text-text-secondary">
                  {selectedInvoice.notes}
                </p>
              </div>
            )}

            {/* Status */}
            <div className="border-t border-border pt-6">
              <p className="text-caption text-text-tertiary uppercase tracking-wider mb-2">
                Status
              </p>
              <Badge variant={getStatusVariant(selectedInvoice.status)} className="text-body">
                {getStatusLabel(selectedInvoice.status)}
              </Badge>
            </div>

            {/* Actions */}
            <div className="flex gap-3 pt-4">
              <Button variant="secondary" className="flex-1" onClick={() => setSelectedInvoice(null)}>
                Close
              </Button>
              {selectedInvoice.balance_due > 0 && (
                <Button variant="primary" className="flex-1" onClick={() => alert('Payment portal coming soon')}>
                  Pay Now
                </Button>
              )}
            </div>
          </div>
        </Modal>
      )}
    </div>
  )
}
