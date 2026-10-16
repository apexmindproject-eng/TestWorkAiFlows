#!/bin/bash
# End-to-end test in an Android emulator (run by .github/workflows/apk.yml): install the x86_64 build, start it,
# wait until the simulation inside it serves its page. Prints the app's log along the way.
set -u
APK=${1:-FlyInABox-x86_64.apk}
adb install -r "$APK"
adb shell am start -n com.flyinabox.app/.MainActivity --ez autostart true
adb forward tcp:8765 tcp:8765
ok=0
for i in $(seq 1 150); do
  sleep 20
  if curl -s --max-time 5 http://127.0.0.1:8765/state | grep -q '"t"'; then ok=1; break; fi
  echo "--- $((i*20)) s"; adb shell run-as com.flyinabox.app sh -c 'tail -n 3 files/fly.log' 2>/dev/null || true
  adb logcat -d -s AndroidRuntime:E 2>/dev/null | tail -n 5 || true
done
echo "=== fly.log"; adb shell run-as com.flyinabox.app sh -c 'tail -n 60 files/fly.log' 2>/dev/null || true
echo "=== logcat (app)"; adb logcat -d 2>/dev/null | grep -iE "flyinabox|AndroidRuntime" | tail -n 40 || true
echo "=== state"; curl -s --max-time 5 http://127.0.0.1:8765/state; echo
[ "$ok" = 1 ]
