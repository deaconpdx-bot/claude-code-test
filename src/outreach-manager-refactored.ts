import { Lead, Contact, Sequence, OutreachRecord, SequenceStep, SendResult } from './types';

/**
 * REFACTORED VERSION - Clean, maintainable, and testable
 * Improvements:
 * - Separated concerns into focused classes
 * - Extracted validation logic into composable validators
 * - Clear single responsibility for each method
 * - Easy to test and extend
 */

// Configuration interfaces for better type safety
interface ComplianceConfig {
  requireLegalBasis: boolean;
  blockHighRisk: boolean;
  reviewHighRisk: boolean;
  cannabisRequiresReview: boolean;
  supplementsRequiresFDA: boolean;
  cosmeticsRequiresFDA: boolean;
}

interface ThrottleConfig {
  blockLowReputation: boolean;
  respectBusinessHours: boolean;
  minFitScore?: number;
  minIntentScore?: number;
}

// Validation result with clear success/failure states
interface ValidationResult {
  valid: boolean;
  reason?: string;
  requiresManualReview?: boolean;
}

/**
 * Handles compliance checks for different industries
 */
class ComplianceValidator {
  constructor(private config: ComplianceConfig) {}

  validateLead(lead: Lead): ValidationResult {
    if (!lead.hasLegalBasis && this.config.requireLegalBasis) {
      return {
        valid: false,
        reason: 'No legal basis for contact',
        requiresManualReview: true
      };
    }

    if (lead.isHighRisk) {
      if (this.config.blockHighRisk) {
        return {
          valid: false,
          reason: 'Lead marked as high risk',
          requiresManualReview: true
        };
      }
      if (this.config.reviewHighRisk) {
        return {
          valid: false,
          reason: 'High risk lead requires manual review',
          requiresManualReview: true
        };
      }
    }

    return { valid: true };
  }

  validateIndustryCompliance(lead: Lead, messageBody: string): ValidationResult {
    if (lead.industry.includes('cannabis')) {
      return this.validateCannabis(messageBody);
    }

    if (lead.industry.includes('supplements')) {
      return this.validateSupplements(messageBody);
    }

    if (lead.industry.includes('cosmetics')) {
      return this.validateCosmetics(messageBody);
    }

    return { valid: true };
  }

  validateCannabisFirstContact(lead: Lead, stepNumber: number): ValidationResult {
    if (lead.industry.includes('cannabis') && stepNumber === 1 && this.config.cannabisRequiresReview) {
      return {
        valid: false,
        reason: 'Cannabis industry requires manual review for first contact',
        requiresManualReview: true
      };
    }
    return { valid: true };
  }

  private validateCannabis(body: string): ValidationResult {
    const prohibitedTerms = ['cure', 'treat', 'medical claims', 'FDA approved'];
    const hasProhibitedTerms = prohibitedTerms.some(term =>
      body.toLowerCase().includes(term)
    );

    if (hasProhibitedTerms) {
      return {
        valid: false,
        reason: 'Cannabis compliance check failed',
        requiresManualReview: true
      };
    }

    return { valid: true };
  }

  private validateSupplements(body: string): ValidationResult {
    if (!this.config.supplementsRequiresFDA) {
      return { valid: true };
    }

    const prohibitedClaims = ['cure', 'treat disease', 'prevent illness'];
    const hasProhibitedClaims = prohibitedClaims.some(claim =>
      body.toLowerCase().includes(claim)
    );

    if (hasProhibitedClaims) {
      return {
        valid: false,
        reason: 'FDA compliance check failed for supplements',
        requiresManualReview: true
      };
    }

    return { valid: true };
  }

  private validateCosmetics(body: string): ValidationResult {
    if (!this.config.cosmeticsRequiresFDA) {
      return { valid: true };
    }

    const prohibitedClaims = ['anti-aging miracle', 'removes wrinkles permanently'];
    const hasProhibitedClaims = prohibitedClaims.some(claim =>
      body.toLowerCase().includes(claim)
    );

    if (hasProhibitedClaims) {
      return {
        valid: false,
        reason: 'Cosmetics compliance check failed',
        requiresManualReview: true
      };
    }

    return { valid: true };
  }
}

/**
 * Handles eligibility checks for outreach
 */
class EligibilityChecker {
  constructor(
    private suppressionList: Set<string>,
    private throttleConfig: ThrottleConfig
  ) {}

  checkContactEligibility(contact: Contact, lead: Lead): ValidationResult {
    if (this.suppressionList.has(contact.email)) {
      return { valid: false, reason: 'Contact in suppression list' };
    }

    if (lead.unsubscribed) {
      return { valid: false, reason: 'Lead unsubscribed' };
    }

    if (contact.optedOut) {
      return { valid: false, reason: 'Contact opted out' };
    }

    return { valid: true };
  }

  checkSequenceEligibility(sequence: Sequence, outreachRecord: OutreachRecord): ValidationResult {
    if (!sequence.active) {
      return { valid: false, reason: 'Sequence not active' };
    }

    if (outreachRecord.status === 'paused' || outreachRecord.status === 'completed') {
      return { valid: false, reason: `Outreach is ${outreachRecord.status}` };
    }

    if (outreachRecord.threadReplied) {
      return { valid: false, reason: 'Thread already replied' };
    }

    return { valid: true };
  }

  checkLeadQuality(lead: Lead): ValidationResult {
    if (this.throttleConfig.minFitScore && lead.fitScore < this.throttleConfig.minFitScore) {
      return {
        valid: false,
        reason: 'Lead fit score too low',
        requiresManualReview: true
      };
    }

    if (this.throttleConfig.minIntentScore && lead.intentScore < this.throttleConfig.minIntentScore) {
      return {
        valid: false,
        reason: 'Lead intent score too low',
        requiresManualReview: true
      };
    }

    return { valid: true };
  }

  checkDomainReputation(domain: string): ValidationResult {
    if (!this.throttleConfig.blockLowReputation) {
      return { valid: true };
    }

    const score = this.calculateDomainScore(domain);
    if (score < 50) {
      return {
        valid: false,
        reason: 'Low domain reputation',
        requiresManualReview: true
      };
    }

    return { valid: true };
  }

  checkBusinessHours(currentTime: Date, timezone: string): ValidationResult {
    if (!this.throttleConfig.respectBusinessHours) {
      return { valid: true };
    }

    const hour = this.getHourInTimezone(currentTime, timezone);
    if (hour < 9 || hour > 17) {
      return { valid: false, reason: 'Outside business hours in lead timezone' };
    }

    return { valid: true };
  }

  private calculateDomainScore(domain: string): number {
    const commonDomains = ['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com'];
    return commonDomains.includes(domain.toLowerCase()) ? 80 : 60;
  }

  private getHourInTimezone(date: Date, timezone: string): number {
    const timezoneOffsets: { [key: string]: number } = {
      'America/New_York': -5,
      'America/Chicago': -6,
      'America/Denver': -7,
      'America/Los_Angeles': -8,
      'UTC': 0
    };
    const offset = timezoneOffsets[timezone] || 0;
    return (date.getUTCHours() + offset + 24) % 24;
  }
}

/**
 * Manages sequence timing and step progression
 */
class SequenceScheduler {
  getNextStep(sequence: Sequence, outreachRecord: OutreachRecord): SequenceStep | null {
    return sequence.steps.find(s => s.stepNumber === outreachRecord.currentStep + 1) || null;
  }

  isStepReady(
    nextStep: SequenceStep,
    outreachRecord: OutreachRecord,
    currentTime: Date
  ): ValidationResult {
    const daysSinceReference = this.calculateDaysSinceReference(outreachRecord, currentTime);

    if (daysSinceReference < nextStep.dayOffset) {
      return { valid: false, reason: 'Not enough time passed since last send' };
    }

    return { valid: true };
  }

  private calculateDaysSinceReference(outreachRecord: OutreachRecord, currentTime: Date): number {
    const referenceTime = outreachRecord.lastSentAt || outreachRecord.startedAt;
    return Math.floor(
      (currentTime.getTime() - referenceTime.getTime()) / (1000 * 60 * 60 * 24)
    );
  }
}

/**
 * Manages daily send limits and throttling
 */
class SendLimiter {
  private dailySendCount = 0;
  private lastResetDate = new Date();
  private dailyLimit = 500;

  canSend(currentTime: Date): ValidationResult {
    this.resetIfNeeded(currentTime);

    if (this.dailySendCount >= this.dailyLimit) {
      return { valid: false, reason: 'Daily send limit reached' };
    }

    return { valid: true };
  }

  recordSend(currentTime: Date): void {
    this.resetIfNeeded(currentTime);
    this.dailySendCount++;
  }

  private resetIfNeeded(currentTime: Date): void {
    if (this.lastResetDate.getDate() !== currentTime.getDate()) {
      this.dailySendCount = 0;
      this.lastResetDate = currentTime;
    }
  }
}

/**
 * Handles email sending operations
 */
class EmailSender {
  async send(to: string, subject: string, body: string): Promise<boolean> {
    // Simulate email sending
    console.log(`Sending email to ${to}: ${subject}`);
    return true;
  }
}

/**
 * Updates state after successful operations
 */
class StateUpdater {
  updateAfterSend(
    lead: Lead,
    outreachRecord: OutreachRecord,
    nextStep: SequenceStep,
    currentTime: Date
  ): void {
    // Update outreach record
    outreachRecord.currentStep = nextStep.stepNumber;
    outreachRecord.lastSentAt = currentTime;

    // Update lead status if needed
    if (lead.status === 'New' || lead.status === 'Qualified') {
      lead.status = 'Contacted';
    }
    lead.lastContactDate = currentTime;
  }

  markAsUnsubscribed(outreachRecord: OutreachRecord): void {
    outreachRecord.status = 'unsubscribed';
  }

  markAsReplied(outreachRecord: OutreachRecord): void {
    outreachRecord.status = 'replied';
  }

  markAsCompleted(outreachRecord: OutreachRecord): void {
    outreachRecord.status = 'completed';
  }
}

/**
 * Main orchestrator - coordinates all validators and operations
 * Now much simpler and easier to understand
 */
export class OutreachManager {
  private complianceValidator: ComplianceValidator;
  private eligibilityChecker: EligibilityChecker;
  private sequenceScheduler: SequenceScheduler;
  private sendLimiter: SendLimiter;
  private emailSender: EmailSender;
  private stateUpdater: StateUpdater;
  private suppressionList: Set<string>;

  constructor(
    complianceConfig: ComplianceConfig,
    throttleConfig: ThrottleConfig
  ) {
    this.suppressionList = new Set();
    this.complianceValidator = new ComplianceValidator(complianceConfig);
    this.eligibilityChecker = new EligibilityChecker(this.suppressionList, throttleConfig);
    this.sequenceScheduler = new SequenceScheduler();
    this.sendLimiter = new SendLimiter();
    this.emailSender = new EmailSender();
    this.stateUpdater = new StateUpdater();
  }

  addToSuppressionList(emails: string[]): void {
    emails.forEach(email => this.suppressionList.add(email));
  }

  /**
   * Process outreach step - now clean and easy to follow
   * Each validation is clearly separated and easy to understand
   */
  async processOutreachStep(
    lead: Lead,
    contact: Contact,
    sequence: Sequence,
    outreachRecord: OutreachRecord,
    currentTime: Date
  ): Promise<SendResult> {
    // Validate send limit
    const limitCheck = this.sendLimiter.canSend(currentTime);
    if (!limitCheck.valid) {
      return this.toSendResult(limitCheck);
    }

    // Validate contact eligibility
    const contactCheck = this.eligibilityChecker.checkContactEligibility(contact, lead);
    if (!contactCheck.valid) {
      if (contactCheck.reason?.includes('unsubscribed') || contactCheck.reason?.includes('opted out')) {
        this.stateUpdater.markAsUnsubscribed(outreachRecord);
      }
      return this.toSendResult(contactCheck);
    }

    // Validate sequence eligibility
    const sequenceCheck = this.eligibilityChecker.checkSequenceEligibility(sequence, outreachRecord);
    if (!sequenceCheck.valid) {
      if (sequenceCheck.reason?.includes('replied')) {
        this.stateUpdater.markAsReplied(outreachRecord);
      }
      return this.toSendResult(sequenceCheck);
    }

    // Get next step
    const nextStep = this.sequenceScheduler.getNextStep(sequence, outreachRecord);
    if (!nextStep) {
      this.stateUpdater.markAsCompleted(outreachRecord);
      return { success: false, reason: 'No more steps in sequence' };
    }

    // Validate timing
    const timingCheck = this.sequenceScheduler.isStepReady(nextStep, outreachRecord, currentTime);
    if (!timingCheck.valid) {
      return this.toSendResult(timingCheck);
    }

    // Validate approval requirement
    if (nextStep.requiresApproval) {
      return {
        success: false,
        reason: 'Step requires manual approval',
        requiresManualReview: true
      };
    }

    // Validate compliance
    const complianceCheck = this.complianceValidator.validateLead(lead);
    if (!complianceCheck.valid) {
      return this.toSendResult(complianceCheck);
    }

    // Validate industry-specific compliance
    const industryCheck = this.complianceValidator.validateIndustryCompliance(lead, nextStep.body);
    if (!industryCheck.valid) {
      return this.toSendResult(industryCheck);
    }

    // Validate cannabis first contact
    const cannabisCheck = this.complianceValidator.validateCannabisFirstContact(lead, nextStep.stepNumber);
    if (!cannabisCheck.valid) {
      return this.toSendResult(cannabisCheck);
    }

    // Validate lead quality
    const qualityCheck = this.eligibilityChecker.checkLeadQuality(lead);
    if (!qualityCheck.valid) {
      return this.toSendResult(qualityCheck);
    }

    // Validate domain reputation
    const domainCheck = this.eligibilityChecker.checkDomainReputation(lead.emailDomain);
    if (!domainCheck.valid) {
      return this.toSendResult(domainCheck);
    }

    // Validate business hours
    const hoursCheck = this.eligibilityChecker.checkBusinessHours(currentTime, lead.timezone);
    if (!hoursCheck.valid) {
      return this.toSendResult(hoursCheck);
    }

    // All validations passed - send the email
    return this.sendOutreach(lead, contact, outreachRecord, nextStep, currentTime);
  }

  private async sendOutreach(
    lead: Lead,
    contact: Contact,
    outreachRecord: OutreachRecord,
    nextStep: SequenceStep,
    currentTime: Date
  ): Promise<SendResult> {
    try {
      const sent = await this.emailSender.send(contact.email, nextStep.subject, nextStep.body);

      if (sent) {
        this.sendLimiter.recordSend(currentTime);
        this.stateUpdater.updateAfterSend(lead, outreachRecord, nextStep, currentTime);
        return { success: true };
      }

      return { success: false, reason: 'Failed to send email' };
    } catch (error) {
      return {
        success: false,
        reason: `Error sending email: ${error}`,
        requiresManualReview: true
      };
    }
  }

  private toSendResult(validation: ValidationResult): SendResult {
    return {
      success: false,
      reason: validation.reason,
      requiresManualReview: validation.requiresManualReview
    };
  }
}
