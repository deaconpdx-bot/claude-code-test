import PageHeader from '@/components/PageHeader'
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/Table'
import Badge from '@/components/ui/Badge'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'
import leadsData from '@/mock-data/leads.json'

export default function LeadsPage() {
  return (
    <div>
      <PageHeader
        title="Leads"
        subtitle="Manage sales opportunities"
        action={
          <Button>Add Lead</Button>
        }
      />

      <Card className="p-0 overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Company</TableHead>
              <TableHead>Contact</TableHead>
              <TableHead>Contact Info</TableHead>
              <TableHead>Source</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Interest</TableHead>
              <TableHead className="text-right">Est. Value</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {leadsData.map((lead) => {
              const badgeVariant = {
                new: 'active' as const,
                contacted: 'default' as const,
                qualified: 'active' as const,
                proposal_sent: 'default' as const,
              }

              const statusLabels = {
                new: 'New',
                contacted: 'Contacted',
                qualified: 'Qualified',
                proposal_sent: 'Proposal Sent',
              }

              return (
                <TableRow key={lead.id}>
                  <TableCell className="font-medium">{lead.companyName}</TableCell>
                  <TableCell>{lead.contactName}</TableCell>
                  <TableCell>
                    <div className="text-text-primary">{lead.email}</div>
                    <div className="text-caption text-text-tertiary mt-1">{lead.phone}</div>
                  </TableCell>
                  <TableCell className="text-text-secondary">{lead.source}</TableCell>
                  <TableCell>
                    <Badge variant={badgeVariant[lead.status as keyof typeof badgeVariant]}>
                      {statusLabels[lead.status as keyof typeof statusLabels]}
                    </Badge>
                  </TableCell>
                  <TableCell>{lead.interestedIn}</TableCell>
                  <TableCell className="text-right font-medium">{lead.estimatedValue}</TableCell>
                  <TableCell className="text-text-secondary">
                    {new Date(lead.createdAt).toLocaleDateString()}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </Card>
    </div>
  )
}
