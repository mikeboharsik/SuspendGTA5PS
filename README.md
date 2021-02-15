# SuspendGTA5PS

### Ever been playing GTA Online when suddenly some rando kills you? It's bad enough that you were in the middle of delivering some business supplies, but now the dude's chasing you down when you spawn and surprise: he's modded his game to be invincible!

### Don't let someone have fun at the expense of your own. Suspend your GTA5.exe process for 15 seconds and you'll land all by yourself in a public session with no need to worry about anyone ruining your good time.

---

# Usage
1. [Ensure you have the latest PowerShell Core installed](https://github.com/PowerShell/PowerShell/releases)
2. Open a PowerShell window in the directory you have this code checked out
    * If you'd like to be able to suspend over your own local network, open the PowerShell window as an administrator
3. Run `./Invoke-SuspendGTA5.ps1`
4. Launch GTA5
5. Whenever you are in an unfair situation, you can kick everyone from your session by bringing up a web browser and navigating to `http://localhost:8080/suspend`; this will suspend GTA5 for 15 seconds and then unsuspend it, leaving you alone in your session to continue as you were