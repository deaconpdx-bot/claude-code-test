# n8n Workflow Debug Report: CoPackLeadGen_Anymailfinder

**Date:** 2026-01-22
**Workflow:** CoPackLeadGen_Anymailfinder
**Status:** FIXED - Complete Workflow Rewrite Provided

---

## Executive Summary

The workflow successfully fetches business listings from SerpAPI but fails to enrich them with emails. Two root causes were identified: a broken n8n expression sending invalid data to AnyEmailFinder, and missing website data from SerpAPI's Google Local results.

---

## Issues Found

### Issue 1: Broken AnyEmailFinder Expression (Critical)

**Problem:** The `jsonBody` field uses invalid nested expression syntax:
```javascript
"domain": "={{ $json.domain_clean }}"
```

**Result:** AnyEmailFinder receives `"="` as the domain value instead of the actual domain.

**Evidence:** API logs showed requests with `"domain": "="` returning 200 OK but no results.

**Fix:** Change body configuration to "Using Fields Below" mode:
- `domain` = `{{ $json.domain_clean }}`
- `limit` = `10`

---

### Issue 2: SerpAPI Not Returning Website Data (Critical)

**Problem:** SerpAPI's `google_local` engine returns business listings without website URLs for most results.

**Evidence:** Sample of 10 records showed:
- `website`: empty for 100%
- `domain_clean`: empty for 100%
- `has_domain`: false for 100%

**Impact:** Without domains, AnyEmailFinder cannot perform lookups regardless of other fixes.

**Fix:** Add a secondary SerpAPI lookup using the regular `google` engine:
```
Query: "{company_name} {address} official website"
Engine: google (not google_local)
Extract: First organic result URL
```

---

### Issue 3: Broken Data Merge (High)

**Problem:** The "Merge Email Data" node uses:
```javascript
const previousData = $node["Advanced Deduplication"].json;
```

This retrieves only the FIRST item from that node, not the matching item per iteration.

**Fix:** Pass company data through the AnyEmailFinder call or use n8n's built-in merge node with item pairing.

---

### Issue 4: Filter Blocking All Data (Medium)

**Problem:** "Filter - Has Email" blocks all records since no emails exist yet.

**Fix:** Disable filter or move it to a later stage. Write all leads to Sheets with an `email_status` field for visibility.

---

### Issue 5: Google Sheets Field Mismatches (Low)

**Problem:** Column mappings reference non-existent fields:
- `businessType` references `$json.businesstype` (doesn't exist)
- `hours` references `$json.hour` (doesn't exist)

**Fix:** Update mappings to match actual field names from upstream nodes.

---

## Recommended Fix Sequence

### Phase 1: Immediate (Get Data to Sheets)
1. Disable "Filter - Has Email"
2. Disable "AnyEmailFinder"
3. Connect "Advanced Deduplication" directly to "Save Enhanced Data"
4. Run workflow to capture all SerpAPI data

### Phase 2: Fix Email Enrichment
1. Fix AnyEmailFinder body configuration (use "Fields Below" mode)
2. Add IF node to skip records without domains
3. Fix "Merge Email Data" node reference

### Phase 3: Add Domain Discovery
1. Add new branch for records missing `domain_clean`
2. Use SerpAPI `google` engine: `"{name} {address} official website"`
3. Extract domain from first organic result
4. Merge back and send to AnyEmailFinder

---

## Data Flow (Fixed)

```
SerpAPI (google_local)
        ↓
Enhanced Processing & Filtering
        ↓
Advanced Deduplication
        ↓
    Has Domain?
    ↓         ↓
   YES        NO
    ↓         ↓
    ↓    SerpAPI Google Search
    ↓    (find website)
    ↓         ↓
    ↓    Extract Domain
    ↓         ↓
    ←---------↓
        ↓
   Has Domain Now?
    ↓         ↓
   YES        NO
    ↓         ↓
AnyEmailFinder  ↓
    ↓         ↓
Merge Email     ↓
    ↓         ↓
    ←---------↓
        ↓
  Save to Sheets (ALL records)
```

---

## Cost Implications

| Action | Estimated API Calls | Notes |
|--------|---------------------|-------|
| Current SerpAPI data | 336 (already paid) | Pinned, reusable |
| Domain discovery (Phase 3) | ~5,000+ | Only for records without websites |
| AnyEmailFinder | ~500-1,000 | Only records with valid domains |

---

## Solution Implemented

A complete rewritten workflow has been provided at:
**`workflows/CoPackLeadGen_Anymailfinder_FIXED.json`**

### Key Changes in Fixed Workflow

1. **Fixed AnyEmailFinder Configuration**
   - Uses `JSON.stringify()` for proper body formatting
   - Added `Bearer` prefix to Authorization header
   - Added `neverError: true` to prevent workflow crashes

2. **Added Domain Discovery**
   - New "Find Website via Google" node uses SerpAPI `google` engine
   - Query: `{company_name} {address} official website`
   - Filters out social media, directories, and aggregators
   - Extracts clean domain from first valid organic result

3. **Fixed Data Merging**
   - Uses `$('NodeName').item.json` for proper item pairing
   - Company data flows correctly through email enrichment
   - All records reach Google Sheets regardless of email status

4. **Added Status Tracking**
   - `emailStatus` field: EMAIL_FOUND, NO_EMAIL_FOUND, NO_DOMAIN, NOT_FOUND
   - `domain_source` field: serpapi_local, google_search, not_found, none

5. **Fixed Google Sheets Mapping**
   - All expressions use correct `={{ $json.fieldName }}` syntax
   - Added new columns: domain_source, emailStatus
   - Removed invalid field references

### Workflow Nodes (16 total)

| Node | Purpose |
|------|---------|
| Schedule Trigger | Initiates workflow |
| Focused Search Parameters | Defines search terms and locations |
| Split Into Batches | Rate limiting |
| Create Search Combinations | Generates query permutations |
| Wait 30 Seconds | API rate limiting |
| SerpAPI Local Search | Fetches business listings |
| Process SerpAPI Results | Extracts and normalizes data |
| Deduplicate | Removes duplicate businesses |
| Has Domain? | Routes based on website availability |
| Find Website via Google | Discovers websites for businesses without them |
| Extract Domain | Parses domain from search results |
| Merge All Records | Combines both branches |
| Has Domain for Email? | Routes to email enrichment |
| AnyEmailFinder | Fetches contact emails |
| Merge Email Data | Combines email with company data |
| Mark No Domain | Adds status for records without domains |
| Merge Final | Combines enriched and non-enriched records |
| Save to Google Sheets | Writes all data to spreadsheet |

---

## Files Modified

- `workflows/CoPackLeadGen_Anymailfinder_FIXED.json` - Complete rewritten workflow
- `docs/n8n-workflow-debug-report.md` - This report

---

## How to Use

1. In n8n, go to **Workflows** → **Import from File**
2. Select `CoPackLeadGen_Anymailfinder_FIXED.json`
3. Verify credentials are connected (SerpAPI, Google Sheets)
4. **Important:** Update Google Sheets headers to match new columns
5. Test with a small batch first before full run

### Google Sheets Headers (Update Row 1)

```
place_id | name | phone | website | domain_clean | contactEmail | contactFirstName | contactLastName | contactPosition | emailConfidence | emailStatus | fullAddress | rating | reviewCount | coPackerCategory | searchQuery | searchLocation | domain_source
```

---

## Cost Estimate for Full Run

| API | Calls | Est. Cost |
|-----|-------|-----------|
| SerpAPI google_local | ~336 | Already paid |
| SerpAPI google (domain discovery) | ~5,000 | ~$50 |
| AnyEmailFinder | ~2,000-4,000 | Depends on plan |

**Recommendation:** Run domain discovery on a subset first to validate before full-scale execution.

