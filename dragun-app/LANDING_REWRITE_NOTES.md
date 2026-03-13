# Landing Rewrite Screenshot Commands

## Before (previous commit)
```bash
git worktree add /tmp/dragun-before HEAD~1
cd /tmp/dragun-before
npm install
npm run dev
# in another terminal
npx playwright screenshot --device="Desktop Chrome" http://localhost:3000/en before-home-desktop.png
npx playwright screenshot --device="iPhone 13" http://localhost:3000/en before-home-mobile.png
```

## After (current branch)
```bash
cd /home/openclaw/.openclaw/workspace/dragun-app
npm install
npm run dev
# in another terminal
npx playwright screenshot --device="Desktop Chrome" http://localhost:3000/en after-home-desktop.png
npx playwright screenshot --device="iPhone 13" http://localhost:3000/en after-home-mobile.png
```
