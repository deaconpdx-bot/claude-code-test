// Lead and contact types
export interface Lead {
  id: string;
  companyName: string;
  industry: string[];
  fitScore: number;
  intentScore: number;
  status: 'New' | 'Qualified' | 'Contacted' | 'Replying' | 'Sample/Quote' | 'Won' | 'Lost';
  unsubscribed: boolean;
  lastContactDate?: Date;
  repliedToLastEmail?: boolean;
  emailDomain: string;
  hasLegalBasis: boolean;
  isHighRisk: boolean;
  timezone: string;
}

export interface Contact {
  id: string;
  leadId: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  optedOut: boolean;
}

// Outreach sequence types
export interface SequenceStep {
  stepNumber: number;
  dayOffset: number;
  subject: string;
  body: string;
  type: 'email' | 'sms' | 'task';
  requiresApproval: boolean;
}

export interface Sequence {
  id: string;
  name: string;
  industry: string;
  steps: SequenceStep[];
  active: boolean;
}

export interface OutreachRecord {
  id: string;
  leadId: string;
  contactId: string;
  sequenceId: string;
  currentStep: number;
  startedAt: Date;
  lastSentAt?: Date;
  status: 'active' | 'paused' | 'completed' | 'replied' | 'unsubscribed';
  threadReplied: boolean;
}

export interface SendResult {
  success: boolean;
  reason?: string;
  requiresManualReview?: boolean;
}
