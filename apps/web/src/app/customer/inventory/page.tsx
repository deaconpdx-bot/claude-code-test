import PageHeader from '@/components/PageHeader'
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/Table'
import Badge from '@/components/ui/Badge'
import Card from '@/components/ui/Card'
import inventoryData from '@/mock-data/inventory.json'

export default function InventoryPage() {
  return (
    <div>
      <PageHeader
        title="Inventory"
        subtitle="Track stock levels and run rates"
      />

      <Card className="p-0 overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>SKU</TableHead>
              <TableHead>Product</TableHead>
              <TableHead>Category</TableHead>
              <TableHead className="text-right">Current Stock</TableHead>
              <TableHead className="text-right">Min Stock</TableHead>
              <TableHead className="text-right">Run Rate/Day</TableHead>
              <TableHead className="text-right">Days Left</TableHead>
              <TableHead>Status</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {inventoryData.map((item) => {
              const badgeVariant = {
                critical: 'active' as const,
                low: 'default' as const,
                healthy: 'muted' as const,
              }

              const daysStyle = {
                critical: 'text-white font-bold',
                low: 'text-text-primary font-semibold',
                healthy: 'text-text-secondary',
              }

              return (
                <TableRow key={item.id}>
                  <TableCell className="font-medium">{item.sku}</TableCell>
                  <TableCell>{item.name}</TableCell>
                  <TableCell className="text-text-secondary">{item.category}</TableCell>
                  <TableCell className="text-right">{item.currentStock.toLocaleString()}</TableCell>
                  <TableCell className="text-right text-text-secondary">{item.minStock.toLocaleString()}</TableCell>
                  <TableCell className="text-right">{item.runRate}</TableCell>
                  <TableCell className={`text-right ${daysStyle[item.status as keyof typeof daysStyle]}`}>
                    {item.daysRemaining.toFixed(1)}
                  </TableCell>
                  <TableCell>
                    <Badge variant={badgeVariant[item.status as keyof typeof badgeVariant]}>
                      {item.status === 'critical' && 'Critical'}
                      {item.status === 'low' && 'Low'}
                      {item.status === 'healthy' && 'Healthy'}
                    </Badge>
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
