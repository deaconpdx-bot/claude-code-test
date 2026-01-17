import { Lead, Contact, Sequence, OutreachRecord, SequenceStep, SendResult } from './types';

/**
 * COMPLEX VERSION - This is intentionally complex and hard to maintain
 * Issues: Deep nesting, multiple responsibilities, unclear logic flow
 */
export class OutreachManager {
  private globalSuppressionList: Set<string> = new Set();
  private dailySendLimit = 500;
  private dailySendCount = 0;
  private lastResetDate = new Date();

  /**
   * This function does way too much and is hard to understand
   * It handles validation, business logic, sending, and logging all in one place
   */
  async processOutreachStep(
    lead: Lead,
    contact: Contact,
    sequence: Sequence,
    outreachRecord: OutreachRecord,
    suppressionList: string[],
    complianceConfig: any,
    throttleConfig: any,
    currentTime: Date
  ): Promise<SendResult> {
    // Reset daily counter if needed
    if (this.lastResetDate.getDate() !== currentTime.getDate()) {
      this.dailySendCount = 0;
      this.lastResetDate = currentTime;
    }

    // Check if we've hit daily limit
    if (this.dailySendCount >= this.dailySendLimit) {
      return { success: false, reason: 'Daily send limit reached' };
    }

    // Add suppression list items
    suppressionList.forEach(email => this.globalSuppressionList.add(email));

    // Check if contact is in suppression list
    if (this.globalSuppressionList.has(contact.email)) {
      return { success: false, reason: 'Contact in suppression list' };
    }

    // Check if lead is unsubscribed
    if (lead.unsubscribed) {
      outreachRecord.status = 'unsubscribed';
      return { success: false, reason: 'Lead unsubscribed' };
    }

    // Check if contact opted out
    if (contact.optedOut) {
      outreachRecord.status = 'unsubscribed';
      return { success: false, reason: 'Contact opted out' };
    }

    // Check if sequence is active
    if (!sequence.active) {
      return { success: false, reason: 'Sequence not active' };
    }

    // Check if outreach is paused or completed
    if (outreachRecord.status === 'paused' || outreachRecord.status === 'completed') {
      return { success: false, reason: `Outreach is ${outreachRecord.status}` };
    }

    // Check if thread has been replied to
    if (outreachRecord.threadReplied) {
      outreachRecord.status = 'replied';
      return { success: false, reason: 'Thread already replied' };
    }

    // Check if there's a next step
    const nextStep = sequence.steps.find(s => s.stepNumber === outreachRecord.currentStep + 1);
    if (!nextStep) {
      outreachRecord.status = 'completed';
      return { success: false, reason: 'No more steps in sequence' };
    }

    // Check if enough time has passed since last send
    if (outreachRecord.lastSentAt) {
      const daysSinceLastSend = Math.floor(
        (currentTime.getTime() - outreachRecord.lastSentAt.getTime()) / (1000 * 60 * 60 * 24)
      );
      if (daysSinceLastSend < nextStep.dayOffset) {
        return { success: false, reason: 'Not enough time passed since last send' };
      }
    } else {
      // First send
      const daysSinceStart = Math.floor(
        (currentTime.getTime() - outreachRecord.startedAt.getTime()) / (1000 * 60 * 60 * 24)
      );
      if (daysSinceStart < nextStep.dayOffset) {
        return { success: false, reason: 'Not enough time passed since sequence start' };
      }
    }

    // Compliance checks
    if (!lead.hasLegalBasis) {
      if (complianceConfig.requireLegalBasis) {
        return {
          success: false,
          reason: 'No legal basis for contact',
          requiresManualReview: true
        };
      }
    }

    // High risk check
    if (lead.isHighRisk) {
      if (complianceConfig.blockHighRisk) {
        return {
          success: false,
          reason: 'Lead marked as high risk',
          requiresManualReview: true
        };
      } else if (complianceConfig.reviewHighRisk && !nextStep.requiresApproval) {
        return {
          success: false,
          reason: 'High risk lead requires manual review',
          requiresManualReview: true
        };
      }
    }

    // Check domain reputation (simulated)
    const domainScore = this.calculateDomainScore(lead.emailDomain);
    if (domainScore < 50) {
      if (throttleConfig.blockLowReputation) {
        return {
          success: false,
          reason: 'Low domain reputation',
          requiresManualReview: true
        };
      }
    }

    // Time-of-day check (don't send outside business hours in their timezone)
    const hour = this.getHourInTimezone(currentTime, lead.timezone);
    if (hour < 9 || hour > 17) {
      if (throttleConfig.respectBusinessHours) {
        return { success: false, reason: 'Outside business hours in lead timezone' };
      }
    }

    // Check if step requires approval
    if (nextStep.requiresApproval) {
      return {
        success: false,
        reason: 'Step requires manual approval',
        requiresManualReview: true
      };
    }

    // Industry-specific checks
    if (lead.industry.includes('cannabis')) {
      if (complianceConfig.cannabisRequiresReview && nextStep.stepNumber === 1) {
        return {
          success: false,
          reason: 'Cannabis industry requires manual review for first contact',
          requiresManualReview: true
        };
      }
      // Cannabis-specific compliance
      if (!this.checkCannabisCompliance(nextStep.body)) {
        return {
          success: false,
          reason: 'Cannabis compliance check failed',
          requiresManualReview: true
        };
      }
    } else if (lead.industry.includes('supplements')) {
      if (complianceConfig.supplementsRequiresFDA && !this.checkFDACompliance(nextStep.body)) {
        return {
          success: false,
          reason: 'FDA compliance check failed for supplements',
          requiresManualReview: true
        };
      }
    } else if (lead.industry.includes('cosmetics')) {
      if (complianceConfig.cosmeticsRequiresFDA && !this.checkCosmeticsCompliance(nextStep.body)) {
        return {
          success: false,
          reason: 'Cosmetics compliance check failed',
          requiresManualReview: true
        };
      }
    }

    // Fit and intent score checks
    if (lead.fitScore < 30) {
      if (throttleConfig.minFitScore && throttleConfig.minFitScore > lead.fitScore) {
        return {
          success: false,
          reason: 'Lead fit score too low',
          requiresManualReview: true
        };
      }
    }

    if (lead.intentScore < 20) {
      if (throttleConfig.minIntentScore && throttleConfig.minIntentScore > lead.intentScore) {
        return {
          success: false,
          reason: 'Lead intent score too low',
          requiresManualReview: true
        };
      }
    }

    // All checks passed, prepare to send
    try {
      // Simulate sending email
      const sent = await this.sendEmail(contact.email, nextStep.subject, nextStep.body);

      if (sent) {
        // Update outreach record
        outreachRecord.currentStep = nextStep.stepNumber;
        outreachRecord.lastSentAt = currentTime;
        this.dailySendCount++;

        // Update lead status if needed
        if (lead.status === 'New' || lead.status === 'Qualified') {
          lead.status = 'Contacted';
        }

        lead.lastContactDate = currentTime;

        return { success: true };
      } else {
        return { success: false, reason: 'Failed to send email' };
      }
    } catch (error) {
      return {
        success: false,
        reason: `Error sending email: ${error}`,
        requiresManualReview: true
      };
    }
  }

  private calculateDomainScore(domain: string): number {
    // Simplified domain scoring
    const commonDomains = ['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com'];
    if (commonDomains.includes(domain.toLowerCase())) {
      return 80;
    }
    return 60;
  }

  private getHourInTimezone(date: Date, timezone: string): number {
    // Simplified timezone conversion
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

  private checkCannabisCompliance(body: string): boolean {
    // Check for prohibited claims
    const prohibitedTerms = ['cure', 'treat', 'medical claims', 'FDA approved'];
    return !prohibitedTerms.some(term => body.toLowerCase().includes(term));
  }

  private checkFDACompliance(body: string): boolean {
    // Simplified FDA compliance check
    const prohibitedClaims = ['cure', 'treat disease', 'prevent illness'];
    return !prohibitedClaims.some(claim => body.toLowerCase().includes(claim));
  }

  private checkCosmeticsCompliance(body: string): boolean {
    // Simplified cosmetics compliance
    const prohibitedClaims = ['anti-aging miracle', 'removes wrinkles permanently'];
    return !prohibitedClaims.some(claim => body.toLowerCase().includes(claim));
  }

  private async sendEmail(to: string, subject: string, body: string): Promise<boolean> {
    // Simulate email sending
    console.log(`Sending email to ${to}: ${subject}`);
    return true;
  }
}
