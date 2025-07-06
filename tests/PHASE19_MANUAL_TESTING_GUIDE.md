# Phase 19 Manual Testing Guide

## 🎯 Current Status
**✅ Data Layer Verified**: All automated tests passed (8/8)  
**✅ Test Programs Created**: 4 programs ready in App Group container  
**✅ Simulators Running**: iPhone 16 + Apple Watch Series 10 booted  
**🔄 Manual Testing**: Ready for UI verification

## 📱 iOS App Testing

### Step 1: Launch iOS ShuttlX App
1. Open Simulator (iPhone 16)
2. Find and tap ShuttlX app icon
3. App should launch and load immediately

### Step 2: Verify Program Loading
**Expected**: 4 test programs should appear in main list:
- ✅ "Phase 19 Sync Test Program" (HIIT, 33 min)
- ✅ "Multi-Test Program 1" (Cardio, 20 min)  
- ✅ "Multi-Test Program 2" (Cardio, 20 min)
- ✅ "Multi-Test Program 3" (Cardio, 20 min)

### Step 3: Test Program Creation
1. Create a new program via ProgramEditorView
2. Save the program
3. Verify it appears in the list immediately
4. Note the program details for watchOS verification

## ⌚ watchOS App Testing

### Step 1: Launch watchOS ShuttlX App  
1. Open Watch Simulator (Apple Watch Series 10)
2. Find and tap ShuttlX app icon
3. App should launch (may take a moment)

### Step 2: Check DebugView
1. Navigate to DebugView in the app
2. **Check sync status information:**
   - App Group container status
   - WatchConnectivity session status  
   - Program count (should show 4-5 programs)
   - Sync operation logs

### Step 3: Verify Program Sync
**Expected**: Same programs as iOS should appear
- Programs may take up to 30 seconds to sync
- Check DebugView for sync activity
- Verify program count matches iOS

## 🔄 Real-time Sync Testing

### Test Scenario 1: iOS → watchOS Sync
1. Create a new program on iOS
2. Save the program
3. **Watch for sync on watchOS:**
   - Check DebugView for sync activity
   - Wait up to 30 seconds for auto-sync
   - Verify new program appears on watchOS

### Test Scenario 2: Sync Status Monitoring
1. Keep DebugView open on watchOS
2. Monitor sync logs during testing
3. Look for successful sync messages
4. Check WatchConnectivity session status

## 📊 Success Criteria

### ✅ Data Layer (COMPLETED)
- [x] App Group container accessible
- [x] Programs stored correctly
- [x] JSON data valid
- [x] Read/write permissions working

### 🔄 UI Layer (IN TESTING)
- [ ] iOS app loads programs from container
- [ ] watchOS app displays programs correctly
- [ ] Program data matches between platforms
- [ ] UI updates reflect data changes

### 🔄 Sync Layer (IN TESTING)  
- [ ] Real-time sync via WatchConnectivity
- [ ] DebugView shows correct sync status
- [ ] Programs sync within 30 seconds
- [ ] No sync errors in logs

## 🐛 Troubleshooting

### If iOS app shows no programs:
- Check app permissions
- Verify App Group entitlement
- Check console logs for errors

### If watchOS sync fails:
- Check WatchConnectivity session in DebugView
- Verify network connectivity between simulators
- Try manual sync trigger if available

### If DebugView shows errors:
- Note error messages
- Check App Group container status
- Verify SharedDataManager initialization

## 📝 Testing Results

**iOS App Status:**
- [ ] App launches successfully
- [ ] 4 test programs visible in main list
- [ ] Program details display correctly
- [ ] New program creation works

**watchOS App Status:**  
- [ ] App launches successfully
- [ ] DebugView accessible and functional
- [ ] Programs sync from iOS (within 30s)
- [ ] Sync status shows no errors

**Real-time Sync Status:**
- [ ] New programs sync iOS → watchOS
- [ ] Sync timing acceptable (<30s)
- [ ] No data loss or corruption
- [ ] DebugView logs show activity

## 🎯 Next Steps

Based on testing results:

**If all tests pass ✅:**
- Phase 19 objectives achieved
- Ready for Phase 20 advanced features
- Document sync performance metrics

**If issues found ❌:**
- Identify specific failure points
- Debug sync mechanism
- Fix issues before proceeding

---
*Manual testing guide for Phase 19 live sync verification*
