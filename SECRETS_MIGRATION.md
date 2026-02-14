# GitHub Secrets Migration

## Status

✅ Workflow updated to use BabyLogly secret names
✅ `APPLE_TEAM_ID` added (value: 83HPSY452Y)

## Secrets that need to be copied from BabyLogly → ShuttlX

The following secrets exist in BabyLogly and need to be added to ShuttlX with these exact names:

### Already in ShuttlX with different names (need new names):

| BabyLogly Secret | ShuttlX Old Name | Status |
|------------------|------------------|--------|
| `IOS_CERTIFICATE_BASE64` | `BUILD_CERTIFICATE_BASE64` | ⚠️ Need to copy |
| `KEY` | `P12_PASSWORD` | ⚠️ Need to copy |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `APP_STORE_CONNECT_API_KEY_CONTENT` | ⚠️ Need to copy |
| `ISSUER_ID` | `APP_STORE_CONNECT_ISSUER_ID` | ⚠️ Need to copy |

### Already matching (no action needed):
- ✅ `APP_STORE_CONNECT_API_KEY_ID`
- ✅ `IOS_PROVISIONING_PROFILE_BASE64`  
- ✅ `WATCH_PROVISIONING_PROFILE_BASE64`
- ✅ `KEYCHAIN_PASSWORD`
- ✅ `APPLE_TEAM_ID` (just added)

## How to copy secrets

**Option 1: GitHub Web UI**
1. Go to https://github.com/muzaparoff/BabyLogly/settings/secrets/actions
2. Copy each value from BabyLogly
3. Go to https://github.com/muzaparoff/shuttlx/settings/secrets/actions
4. Add each secret with the NEW name

**Option 2: GitHub CLI** (requires secret values)
```bash
# You'll need the actual values from BabyLogly
gh secret set IOS_CERTIFICATE_BASE64 --body "..." --repo muzaparoff/shuttlx
gh secret set KEY --body "..." --repo muzaparoff/shuttlx
gh secret set APP_STORE_CONNECT_API_KEY_BASE64 --body "..." --repo muzaparoff/shuttlx
gh secret set ISSUER_ID --body "..." --repo muzaparoff/shuttlx
```

## Verification

After copying, test with:
```bash
gh workflow run deploy.yml --repo muzaparoff/shuttlx
```

Or wait for next push to `main` branch.
