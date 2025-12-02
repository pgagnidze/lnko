# VHS tape for lnko demo
# Run with: vhs demo.tape
#
# Before recording, ensure clean state:
#   lnko unlink -d ~/Development/personal/dotfiles/config bash git nvim ghostty bin
#   rm -rf ~/.lnko-backup
#   rm -f ~/.gitconfig ~/.bashrc ~/.bash_profile

Output demo.gif

Set Shell "bash"
Set FontSize 18
Set Width 1280
Set Height 720
Set Theme "OneDark"
Set TypingSpeed 50ms

Hide
Type "cd ~/Development/personal/dotfiles"
Enter
Sleep 300ms
Show

Type "lnko status -d config"
Enter
Sleep 2s

Type "lnko link -d config bash git"
Enter
Sleep 2s

Type "lnko status -d config"
Enter
Sleep 2s

Hide
Type "rm ~/.gitconfig && echo 'my local config' > ~/.gitconfig"
Enter
Sleep 300ms
Show

Type "lnko status -d config"
Enter
Sleep 2s

Type "lnko link -d config git"
Enter
Sleep 1500ms

Type "d"
Enter
Sleep 2500ms

Type "b"
Enter
Sleep 2s

Type "lnko status -d config"
Enter
Sleep 2s

Type "ls -a ~/.lnko-backup/"
Enter
Sleep 2s

Sleep 500ms
