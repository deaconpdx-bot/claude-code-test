import { OutreachManager as ComplexManager } from './outreach-manager-complex';
import { OutreachManager as RefactoredManager } from './outreach-manager-refactored';
import { Lead, Contact, Sequence, OutreachRecord } from './types';

describe('Outreach Manager - Behavior Verification', () => {
  // Test data factory
  const createLead = (overrides: Partial<Lead> = {}): Lead => ({
    id: '1',
    companyName: 'Test Company',
    industry: ['cannabis'],
    fitScore: 75,
    intentScore: 60,
    status: 'New',
    unsubscribed: false,
    emailDomain: 'testcompany.com',
    hasLegalBasis: true,
    isHighRisk: false,
    timezone: 'America/Los_Angeles',
    ...overrides
  });

  const createContact = (overrides: Partial<Contact> = {}): Contact => ({
    id: '1',
    leadId: '1',
    email: 'test@testcompany.com',
    firstName: 'John',
    lastName: 'Doe',
    role: 'CEO',
    optedOut: false,
    ...overrides
  });

  const createSequence = (overrides: Partial<Sequence> = {}): Sequence => ({
    id: '1',
    name: 'Cannabis Outreach',
    industry: 'cannabis',
    active: true,
    steps: [
      {
        stepNumber: 1,
        dayOffset: 0,
        subject: 'Premium packaging solutions',
        body: 'We offer compliant packaging for your products.',
        type: 'email',
        requiresApproval: false
      },
      {
        stepNumber: 2,
        dayOffset: 2,
        subject: 'Follow up',
        body: 'Just checking in about our packaging solutions.',
        type: 'email',
        requiresApproval: false
      }
    ],
    ...overrides
  });

  const createOutreachRecord = (overrides: Partial<OutreachRecord> = {}): OutreachRecord => ({
    id: '1',
    leadId: '1',
    contactId: '1',
    sequenceId: '1',
    currentStep: 0,
    startedAt: new Date('2024-01-01'),
    status: 'active',
    threadReplied: false,
    ...overrides
  });

  const complianceConfig = {
    requireLegalBasis: true,
    blockHighRisk: true,
    reviewHighRisk: true,
    cannabisRequiresReview: false,
    supplementsRequiresFDA: true,
    cosmeticsRequiresFDA: true
  };

  const throttleConfig = {
    blockLowReputation: false,
    respectBusinessHours: false,
    minFitScore: 30,
    minIntentScore: 20
  };

  describe('Both implementations should behave identically', () => {
    test('should successfully send when all conditions are met', async () => {
      const lead = createLead();
      const contact = createContact();
      const sequence = createSequence();
      const outreachRecord = createOutreachRecord();
      const currentTime = new Date('2024-01-01T10:00:00');

      const complexManager = new ComplexManager();
      const refactoredManager = new RefactoredManager(complianceConfig, throttleConfig);

      const complexResult = await complexManager.processOutreachStep(
        lead,
        contact,
        sequence,
        outreachRecord,
        [],
        complianceConfig,
        throttleConfig,
        currentTime
      );

      // Reset for refactored test
      const lead2 = createLead();
      const outreachRecord2 = createOutreachRecord();

      const refactoredResult = await refactoredManager.processOutreachStep(
        lead2,
        contact,
        sequence,
        outreachRecord2,
        currentTime
      );

      expect(complexResult.success).toBe(refactoredResult.success);
      expect(complexResult.success).toBe(true);
    });

    test('should reject when lead is unsubscribed', async () => {
      const lead = createLead({ unsubscribed: true });
      const contact = createContact();
      const sequence = createSequence();
      const outreachRecord = createOutreachRecord();
      const currentTime = new Date('2024-01-01T10:00:00');

      const complexManager = new ComplexManager();
      const refactoredManager = new RefactoredManager(complianceConfig, throttleConfig);

      const complexResult = await complexManager.processOutreachStep(
        lead,
        contact,
        sequence,
        outreachRecord,
        [],
        complianceConfig,
        throttleConfig,
        currentTime
      );

      const lead2 = createLead({ unsubscribed: true });
      const outreachRecord2 = createOutreachRecord();

      const refactoredResult = await refactoredManager.processOutreachStep(
        lead2,
        contact,
        sequence,
        outreachRecord2,
        currentTime
      );

      expect(complexResult.success).toBe(false);
      expect(refactoredResult.success).toBe(false);
      expect(complexResult.reason).toContain('unsubscribed');
      expect(refactoredResult.reason).toContain('unsubscribed');
    });

    test('should reject when contact opted out', async () => {
      const lead = createLead();
      const contact = createContact({ optedOut: true });
      const sequence = createSequence();
      const outreachRecord = createOutreachRecord();
      const currentTime = new Date('2024-01-01T10:00:00');

      const complexManager = new ComplexManager();
      const refactoredManager = new RefactoredManager(complianceConfig, throttleConfig);

      const complexResult = await complexManager.processOutreachStep(
        lead,
        contact,
        sequence,
        outreachRecord,
        [],
        complianceConfig,
        throttleConfig,
        currentTime
      );

      const lead2 = createLead();
      const contact2 = createContact({ optedOut: true });
      const outreachRecord2 = createOutreachRecord();

      const refactoredResult = await refactoredManager.processOutreachStep(
        lead2,
        contact2,
        sequence,
        outreachRecord2,
        currentTime
      );

      expect(complexResult.success).toBe(false);
      expect(refactoredResult.success).toBe(false);
      expect(complexResult.reason).toContain('opted out');
      expect(refactoredResult.reason).toContain('opted out');
    });

    test('should reject when thread already replied', async () => {
      const lead = createLead();
      const contact = createContact();
      const sequence = createSequence();
      const outreachRecord = createOutreachRecord({ threadReplied: true });
      const currentTime = new Date('2024-01-01T10:00:00');

      const complexManager = new ComplexManager();
      const refactoredManager = new RefactoredManager(complianceConfig, throttleConfig);

      const complexResult = await complexManager.processOutreachStep(
        lead,
        contact,
        sequence,
        outreachRecord,
        [],
        complianceConfig,
        throttleConfig,
        currentTime
      );

      const lead2 = createLead();
      const outreachRecord2 = createOutreachRecord({ threadReplied: true });

      const refactoredResult = await refactoredManager.processOutreachStep(
        lead2,
        contact,
        sequence,
        outreachRecord2,
        currentTime
      );

      expect(complexResult.success).toBe(false);
      expect(refactoredResult.success).toBe(false);
      expect(complexResult.reason).toContain('replied');
      expect(refactoredResult.reason).toContain('replied');
    });

    test('should reject when high risk and config blocks it', async () => {
      const lead = createLead({ isHighRisk: true });
      const contact = createContact();
      const sequence = createSequence();
      const outreachRecord = createOutreachRecord();
      const currentTime = new Date('2024-01-01T10:00:00');

      const complexManager = new ComplexManager();
      const refactoredManager = new RefactoredManager(complianceConfig, throttleConfig);

      const complexResult = await complexManager.processOutreachStep(
        lead,
        contact,
        sequence,
        outreachRecord,
        [],
        complianceConfig,
        throttleConfig,
        currentTime
      );

      const lead2 = createLead({ isHighRisk: true });
      const outreachRecord2 = createOutreachRecord();

      const refactoredResult = await refactoredManager.processOutreachStep(
        lead2,
        contact,
        sequence,
        outreachRecord2,
        currentTime
      );

      expect(complexResult.success).toBe(false);
      expect(refactoredResult.success).toBe(false);
      expect(complexResult.requiresManualReview).toBe(true);
      expect(refactoredResult.requiresManualReview).toBe(true);
    });

    test('should reject when fit score is too low', async () => {
      const lead = createLead({ fitScore: 20 });
      const contact = createContact();
      const sequence = createSequence();
      const outreachRecord = createOutreachRecord();
      const currentTime = new Date('2024-01-01T10:00:00');

      const complexManager = new ComplexManager();
      const refactoredManager = new RefactoredManager(complianceConfig, throttleConfig);

      const complexResult = await complexManager.processOutreachStep(
        lead,
        contact,
        sequence,
        outreachRecord,
        [],
        complianceConfig,
        throttleConfig,
        currentTime
      );

      const lead2 = createLead({ fitScore: 20 });
      const outreachRecord2 = createOutreachRecord();

      const refactoredResult = await refactoredManager.processOutreachStep(
        lead2,
        contact,
        sequence,
        outreachRecord2,
        currentTime
      );

      expect(complexResult.success).toBe(false);
      expect(refactoredResult.success).toBe(false);
      expect(complexResult.reason).toContain('fit score');
      expect(refactoredResult.reason).toContain('fit score');
    });

    test('should reject when step requires approval', async () => {
      const lead = createLead();
      const contact = createContact();
      const sequence = createSequence({
        steps: [
          {
            stepNumber: 1,
            dayOffset: 0,
            subject: 'Test',
            body: 'Test body',
            type: 'email',
            requiresApproval: true
          }
        ]
      });
      const outreachRecord = createOutreachRecord();
      const currentTime = new Date('2024-01-01T10:00:00');

      const complexManager = new ComplexManager();
      const refactoredManager = new RefactoredManager(complianceConfig, throttleConfig);

      const complexResult = await complexManager.processOutreachStep(
        lead,
        contact,
        sequence,
        outreachRecord,
        [],
        complianceConfig,
        throttleConfig,
        currentTime
      );

      const lead2 = createLead();
      const outreachRecord2 = createOutreachRecord();

      const refactoredResult = await refactoredManager.processOutreachStep(
        lead2,
        contact,
        sequence,
        outreachRecord2,
        currentTime
      );

      expect(complexResult.success).toBe(false);
      expect(refactoredResult.success).toBe(false);
      expect(complexResult.requiresManualReview).toBe(true);
      expect(refactoredResult.requiresManualReview).toBe(true);
    });
  });
});
